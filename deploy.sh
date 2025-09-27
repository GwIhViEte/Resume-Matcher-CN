#!/usr/bin/env bash
# deploy.sh - 菜单式一键部署
# 适用结构：根 package.json（可选）、apps/backend（Python/uv，可选）、apps/frontend（Node，可选）
# 生产优先 docker compose；无 compose 则使用 PM2 进行持久化（生成 ecosystem.config.js 并开机自启）

# ========================= 基础设置与稳定错误捕捉 =========================
set -Eeuo pipefail
IFS=$'\n\t'
export PYTHONDONTWRITEBYTECODE=1

# DEBUG：DEPLOY_DEBUG=1 ./deploy.sh
if [[ "${DEPLOY_DEBUG:-0}" == "1" ]]; then
  set -x
  export PS4='+[$(date "+%H:%M:%S")] '
fi

# 让 ERR trap 也在函数/子进程里生效；任何命令失败时打印具体命令、退出码、文件与行号
set -o errtrace
trap 'rc=$?; cmd=$BASH_COMMAND; printf "💥 命令失败：%q (exit=%d) at %s:%d\n" "$cmd" "$rc" "${BASH_SOURCE[0]}" "${LINENO}"; exit $rc' ERR

# ========================= 基本信息 =========================
APP_NAME="resume-matcher-cn"
RUNTIME_DIR=".deploy_runtime"
mkdir -p "$RUNTIME_DIR"

# ========================= 超时/重试配置（防卡死） =========================
APT_TIMEOUT=600           # apt 超时（秒）
CURL_CONNECT_TIMEOUT=15   # curl 连接超时（秒）
CURL_MAX_TIME=180         # curl 请求总体超时（秒）
NPM_FETCH_TIMEOUT=120000  # npm fetch 超时（毫秒）
NPM_FETCH_RETRIES=5
UV_HTTP_TIMEOUT=120       # uv http 超时（秒）
PIP_DEFAULT_TIMEOUT=120   # pip 超时（秒）

# 给子进程生效（当前会话）
export UV_HTTP_TIMEOUT PIP_DEFAULT_TIMEOUT
export NPM_CONFIG_FETCH_TIMEOUT="$NPM_FETCH_TIMEOUT"
export NPM_CONFIG_FETCH_RETRIES="$NPM_FETCH_RETRIES"
export NPM_CONFIG_FETCH_RETRY_FACTOR=2

# ========================= 镜像 / 代理 =========================
NPM_REGISTRY_DEFAULT="https://registry.npmmirror.com"
PIP_INDEX_DEFAULT="https://pypi.tuna.tsinghua.edu.cn/simple"
UV_INDEX_DEFAULT="$PIP_INDEX_DEFAULT"
HTTP_PROXY_DEFAULT=""
HTTPS_PROXY_DEFAULT=""

CONF="$RUNTIME_DIR/config.env"
if [[ -f "$CONF" ]]; then
  # shellcheck disable=SC1090
  source "$CONF"
fi

# ========================= 工具函数 =========================
info() { echo -e "ℹ️  $*"; }
ok()   { echo -e "✅ $*"; }
err()  { echo -e "❌ $*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

persist_conf() {
  cat >"$CONF" <<EOF
NPM_REGISTRY_DEFAULT="${NPM_REGISTRY_DEFAULT}"
PIP_INDEX_DEFAULT="${PIP_INDEX_DEFAULT}"
UV_INDEX_DEFAULT="${UV_INDEX_DEFAULT}"
HTTP_PROXY_DEFAULT="${HTTP_PROXY_DEFAULT}"
HTTPS_PROXY_DEFAULT="${HTTPS_PROXY_DEFAULT}"
EOF
  ok "配置已保存到 $CONF"
}

apply_session_mirrors_and_proxy() {
  export NPM_CONFIG_REGISTRY="${NPM_REGISTRY_DEFAULT}"
  export PIP_INDEX_URL="${PIP_INDEX_DEFAULT}"
  export UV_INDEX_URL="${UV_INDEX_DEFAULT}"
  [[ -n "${HTTP_PROXY_DEFAULT}"  ]] && export HTTP_PROXY="${HTTP_PROXY_DEFAULT}"  && export http_proxy="${HTTP_PROXY_DEFAULT}"
  [[ -n "${HTTPS_PROXY_DEFAULT}" ]] && export HTTPS_PROXY="${HTTPS_PROXY_DEFAULT}" && export https_proxy="${HTTPS_PROXY_DEFAULT}"
  info "会话镜像与代理：npm=$NPM_CONFIG_REGISTRY, pip=$PIP_INDEX_URL, proxy=${HTTP_PROXY_DEFAULT:-none}"
}

# 带超时与重试的执行器
# 用法：run_with_retry "描述" 超时(秒) 重试次数 -- cmd arg1 ...
run_with_retry() {
  local label="$1"; shift
  local timeout_s="$1"; shift
  local retries="$1"; shift
  echo "➡️  ${label}（超时 ${timeout_s}s，重试 ${retries} 次）"
  local attempt=1
  while :; do
    if timeout --preserve-status "${timeout_s}" "$@"; then
      echo "✅ ${label} 成功"
      return 0
    fi
    echo "⚠️  ${label} 失败（第 ${attempt} 次）"
    if (( attempt >= retries )); then
      echo "❌ ${label} 重试用尽"
      return 1
    fi
    attempt=$((attempt+1))
    sleep 2
  done
}

# ========================= 依赖与安装 =========================
auto_fix_deps() {
  local need=(bash curl make git python3 pip3 node npm)
  local miss=()
  for b in "${need[@]}"; do have "$b" || miss+=("$b"); done
  if ((${#miss[@]})); then
    info "缺失依赖：${miss[*]}，用 apt 安装（需 sudo）"
    export DEBIAN_FRONTEND=noninteractive
    run_with_retry "apt-get update"  "$APT_TIMEOUT" 2 sudo apt-get update -y
    run_with_retry "apt-get install 基础工具" "$APT_TIMEOUT" 2 sudo apt-get install -y \
      bash curl make git python3 python3-pip nodejs npm coreutils
  fi
  ok "基础依赖就绪"
}

install_or_update_uv() {
  if have uv; then
    ok "uv 已存在：$(uv --version || true)"
    return 0
  fi
  info "开始安装 uv（镜像回退 + 超时）..."
  local urls=(
    "https://mirror.ghproxy.com/https://astral.sh/uv/install.sh"
    "https://ghproxy.com/https://astral.sh/uv/install.sh"
    "https://astral.sh/uv/install.sh"
  )
  local tmp; tmp="$(mktemp)"
  for u in "${urls[@]}"; do
    info "获取安装脚本：$u"
    if curl -fsSL --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_MAX_TIME" "$u" -o "$tmp"; then
      sed -i \
        -e 's#https://github.com#https://mirror.ghproxy.com/https://github.com#g' \
        -e 's#https://objects.githubusercontent.com#https://mirror.ghproxy.com/https://objects.githubusercontent.com#g' \
        "$tmp"
      if timeout "$CURL_MAX_TIME" bash "$tmp"; then
        rm -f "$tmp"
        export PATH="$HOME/.local/bin:$PATH"
        ok "uv 安装完成"
        return 0
      fi
    fi
  done
  err "uv 安装失败（网络或代理问题）"
  return 1
}

install_root_node() {
  if [[ -f package.json ]]; then
    info "安装根依赖..."
    if [[ -f package-lock.json ]]; then
      # 关键：忽略根 install 脚本，避免触发子项目二次安装导致卡顿
      run_with_retry "npm ci (root)" 600 2 npm ci --no-fund --no-audit --ignore-scripts
    else
      run_with_retry "npm install (root)" 900 2 npm install --no-fund --no-audit --ignore-scripts
    fi
    ok "根依赖安装完成"
  fi
}

install_frontend_node() {
  if [[ -d apps/frontend ]]; then
    info "安装前端依赖..."
    (
      cd apps/frontend
      if [[ -f package-lock.json ]]; then
        run_with_retry "npm ci (frontend)" 600 2 npm ci --no-fund --no-audit --prefer-offline --progress=false
      else
        run_with_retry "npm install (frontend)" 900 2 npm install --no-fund --no-audit --prefer-offline --progress=false
      fi
    )
    ok "前端依赖安装完成"
  fi
}

# ---------- PDF 解析环境（系统依赖 + Python 依赖兜底） ----------
install_pdf_runtime() {
  info "安装 PDF 解析系统依赖（poppler/tesseract/imagemagick/ghostscript/中文字体）..."
  export DEBIAN_FRONTEND=noninteractive
  run_with_retry "apt-get update"  "$APT_TIMEOUT" 2 sudo apt-get update -y
  run_with_retry "apt-get install pdf deps" "$APT_TIMEOUT" 2 sudo apt-get install -y \
    poppler-utils ghostscript imagemagick \
    tesseract-ocr libtesseract-dev tesseract-ocr-chi-sim tesseract-ocr-chi-tra \
    fontconfig fonts-noto-cjk libcairo2 libpango-1.0-0 libxml2
  patch_imagemagick_policy
  ok "系统依赖已安装"
}

patch_imagemagick_policy() {
  # ImageMagick 在不少发行版默认禁用 PDF/PS 读取；这里改为只读（更安全）
  local policy6="/etc/ImageMagick-6/policy.xml"
  local policy7="/etc/ImageMagick-7/policy.xml"
  local edited=false
  for f in "$policy6" "$policy7"; do
    if [[ -f "$f" ]]; then
      sudo cp -a "$f" "${f}.bak" || true
      sudo sed -i \
        -e 's#<policy domain="coder" rights="none" pattern="PDF" />#<policy domain="coder" rights="read" pattern="PDF" />#g' \
        -e 's#<policy domain="coder" rights="none" pattern="PS" />#<policy domain="coder" rights="read" pattern="PS" />#g' \
        -e 's#<policy domain="coder" rights="none" pattern="EPS" />#<policy domain="coder" rights="read" pattern="EPS" />#g' \
        "$f" && edited=true
    fi
  done
  $edited && ok "已调整 ImageMagick policy（PDF/PS/EPS 允许只读）" || info "未发现需要调整的 ImageMagick policy，跳过"
}

install_backend_py() {
  if [[ -d apps/backend ]]; then
    info "安装后端依赖..."
    (
      cd apps/backend
      [[ -d .venv ]] || uv venv
      # shellcheck disable=SC1091
      source .venv/bin/activate
      if [[ -f pyproject.toml ]]; then
        if [[ -f uv.lock || -f requirements.txt ]]; then
          run_with_retry "uv sync (backend)" 900 2 uv sync
          if [[ -f requirements.txt ]]; then
            run_with_retry "uv pip install -r requirements.txt (backend)" 900 2 uv pip install -r requirements.txt --index-url "$PIP_INDEX_URL"
          fi
        else
          run_with_retry "uv pip install -e . (backend)" 900 2 uv pip install -e . --index-url "$PIP_INDEX_URL"
        fi
      else
        run_with_retry "uv pip install -e . (backend legacy)" 900 2 uv pip install -e . --index-url "$PIP_INDEX_URL"
      fi
      # 兜底：无论项目声明如何，都确保 PDF 常用包到位（已装则跳过）
      run_with_retry "安装后端 PDF 依赖" 900 2 uv pip install pdfplumber pdfminer.six pymupdf pillow pytesseract
    )
    ok "后端依赖安装完成"
  fi
}

action_install_pdf_env() {
  apply_session_mirrors_and_proxy
  install_pdf_runtime
  # 后端虚拟环境的 Python 依赖也顺手确保一下
  if [[ -d apps/backend ]]; then
    (
      cd apps/backend
      [[ -d .venv ]] || uv venv
      source .venv/bin/activate
      run_with_retry "安装后端 PDF 依赖" 900 2 uv pip install pdfplumber pdfminer.six pymupdf pillow pytesseract
    )
  fi
  ok "🎉 PDF 解析环境已就绪"
}

create_envs_if_needed() {
  local changed=false

  if [[ -f .env.example && ! -f .env ]]; then
    cp .env.example .env
    ok "已从 .env.example 生成 .env"
    changed=true
  fi

  if [[ -d apps/backend ]]; then
    if [[ -f apps/backend/.env.sample && ! -f apps/backend/.env ]]; then
      cp apps/backend/.env.sample apps/backend/.env
      ok "后端 .env 已生成"
      changed=true
    fi
  fi

  if [[ -d apps/frontend ]]; then
    if [[ -f apps/frontend/.env.sample && ! -f apps/frontend/.env ]]; then
      cp apps/frontend/.env.sample apps/frontend/.env
      ok "前端 .env 已生成"
      changed=true
    fi
  fi

  # 即使没有任何文件可复制，也不算失败
  return 0
}

# ========================= Git / Compose =========================
git_pull_if_repo() {
  if [[ -d .git ]]; then
    info "检测到 Git 仓库，git pull..."
    git fetch --all --prune
    git pull --rebase --autostash || { err "git pull 失败，请手动解决冲突后重试"; return 1; }
    ok "代码已更新"
  else
    info "非 git 目录，跳过更新代码"
  fi
}

has_compose() { [[ -f docker-compose.yml || -f compose.yml ]]; }

compose_up() {
  if have docker && (have docker-compose || have docker compose); then
    local cmd=(docker compose)
    have docker-compose && cmd=(docker-compose)
    run_with_retry "compose build+up -d" 1200 1 "${cmd[@]}" up -d --build
  else
    err "未安装 docker / docker compose"
    return 1
  fi
}

compose_down() {
  if have docker && (have docker-compose || have docker compose); then
    local cmd=(docker compose)
    have docker-compose && cmd=(docker-compose)
    "${cmd[@]}" down || true
  fi
}

# ========================= PM2（持久化） =========================
ensure_pm2() {
  if ! have pm2; then
    info "安装 pm2..."
    run_with_retry "npm i -g pm2" 600 1 npm i -g pm2
  fi
  ok "pm2 就绪：$(pm2 -v)"
}

pm2_write_ecosystem() {
  cat > ecosystem.config.js <<'EOF'
module.exports = {
  apps: [
    {
      name: "resume-backend",
      cwd: "apps/backend",
      script: "uv",
      args: "run uvicorn app.main:app --host 0.0.0.0 --port 8000",
      interpreter: null,
      instances: 1,                  // SQLite 单进程写
      exec_mode: "fork",
      autorestart: true,
      max_memory_restart: "512M",
      env: {
        "PYTHONUNBUFFERED": "1",
        "UV_HTTP_TIMEOUT": "120"
      }
    },
    {
      name: "resume-frontend",
      cwd: "apps/frontend",
      script: "npm",
      args: "start",
      interpreter: null,
      instances: 1,
      exec_mode: "fork",
      autorestart: true,
      max_memory_restart: "512M",
      env: {
        "NODE_ENV": "production",
        "PORT": "3000"
      }
    }
  ]
}
EOF
  ok "已生成 ecosystem.config.js"
}

pm2_start_and_persist() {
  ensure_pm2
  [[ -f ecosystem.config.js ]] || pm2_write_ecosystem
  info "使用 PM2 启动或重启应用..."
  pm2 start ecosystem.config.js || pm2 restart all
  pm2 save
  # 开机自启（尽量自动执行；若需要 sudo，将尝试调用）
  if have sudo; then
    sudo pm2 startup -u "$USER" --hp "$HOME" >/dev/null 2>&1 || pm2 startup >/dev/null 2>&1 || true
  else
    pm2 startup >/dev/null 2>&1 || true
  fi
  ok "PM2 已持久化（崩溃/重启自动拉起）"
}

# ========================= 启停 / 日志 / 状态 =========================
pid_file_dev="$RUNTIME_DIR/${APP_NAME}_dev.pid"
log_dev="$RUNTIME_DIR/${APP_NAME}_dev.log"

detect_scripts() {
  HAS_NPM_DEV=false; HAS_NPM_START=false; HAS_NPM_BUILD=false
  if [[ -f package.json ]]; then
    local pkg; pkg="$(cat package.json)"
    grep -q '"dev"\s*:'   <<<"$pkg" && HAS_NPM_DEV=true
    grep -q '"start"\s*:' <<<"$pkg" && HAS_NPM_START=true
    grep -q '"build"\s*:' <<<"$pkg" && HAS_NPM_BUILD=true
  fi
}

action_install() {
  apply_session_mirrors_and_proxy || { err "apply_session_mirrors_and_proxy 失败"; return 1; }

  echo "[STEP] auto_fix_deps"
  auto_fix_deps || { err "auto_fix_deps 失败"; return 1; }

  echo "[STEP] install_or_update_uv"
  install_or_update_uv || { err "install_or_update_uv 失败"; return 1; }

  echo "[STEP] create_envs_if_needed"
  create_envs_if_needed || { err "create_envs_if_needed 失败"; return 1; }

  echo "[STEP] install_root_node"
  install_root_node || { err "install_root_node 失败"; return 1; }

  echo "[STEP] install_backend_py"
  install_backend_py || { err "install_backend_py 失败"; return 1; }

  echo "[STEP] install_frontend_node"
  install_frontend_node || { err "install_frontend_node 失败"; return 1; }

  echo "[STEP] install_pdf_env"
  action_install_pdf_env || { err "install_pdf_env 失败"; return 1; }

  ok "🎉 安装/初始化完成"
}

action_update() {
  apply_session_mirrors_and_proxy
  git_pull_if_repo
  action_install
}

action_build_root() {
  apply_session_mirrors_and_proxy
  if [[ -f package.json ]]; then
    info "开始构建（root：npm run build）..."
    if [[ ! -d node_modules ]]; then
      if [[ -f package-lock.json ]]; then
        run_with_retry "npm ci (root)" 600 2 npm ci --no-fund --no-audit --ignore-scripts
      else
        run_with_retry "npm install (root)" 900 2 npm install --no-fund --no-audit --ignore-scripts
      fi
    fi
    if grep -q '"build"\s*:' package.json; then
      run_with_retry "npm run build (root)" 1200 1 bash -lc "CI=1 NEXT_TELEMETRY_DISABLED=1 npm run build </dev/null"
      ok "构建完成：root"
    else
      err "package.json 未定义 build 脚本"
      return 1
    fi
  else
    err "未找到 package.json"
    return 1
  fi
}

action_start_dev() {
  apply_session_mirrors_and_proxy
  detect_scripts
  if [[ "$HAS_NPM_DEV" == true ]]; then
    info "以 npm run dev 启动（日志：$log_dev）"
    nohup bash -lc "npm run dev" >"$log_dev" 2>&1 &
    echo $! >"$pid_file_dev"
    ok "开发服务已启动 (PID $(cat "$pid_file_dev"))"
  else
    err "未检测到根目录的 npm run dev；请到具体子项目手动启动或添加 dev 脚本"
    return 1
  fi
}

action_start_prod() {
  apply_session_mirrors_and_proxy
  detect_scripts
  if has_compose; then
    info "检测到 docker compose，后台启动..."
    compose_up
    ok "生产服务已通过 compose 启动"
  elif [[ "$HAS_NPM_BUILD" == true || "$HAS_NPM_START" == true ]]; then
    info "使用 npm 构建生产包..."
    [[ "$HAS_NPM_BUILD" == true ]] && run_with_retry "npm run build (prod)" 1200 1 bash -lc "CI=1 NEXT_TELEMETRY_DISABLED=1 npm run build </dev/null" || true
    info "切换为 PM2 持久化运行..."
    pm2_start_and_persist
  else
    err "未检测到 compose 或 start/build 脚本，无法自动启动生产服务"
    return 1
  fi
}

action_stop() {
  local stopped=false
  # 停 nohup 进程（旧方式）
  if [[ -f "$pid_file_dev" ]]; then
    local pid; pid="$(cat "$pid_file_dev")"
    if ps -p "$pid" >/dev/null 2>&1; then
      kill "$pid" || true
      stopped=true
      ok "已停止开发进程 PID $pid"
    fi
    rm -f "$pid_file_dev"
  fi
  if [[ -f "$RUNTIME_DIR/${APP_NAME}_prod.pid" ]]; then
    local p; p="$(cat "$RUNTIME_DIR/${APP_NAME}_prod.pid")"
    if ps -p "$p" >/dev/null 2>&1; then
      kill "$p" || true
      stopped=true
      ok "已停止生产进程 PID $p"
    fi
    rm -f "$RUNTIME_DIR/${APP_NAME}_prod.pid"
  fi
  # 停 PM2
  if have pm2; then
    pm2 stop resume-backend  >/dev/null 2>&1 || true
    pm2 stop resume-frontend >/dev/null 2>&1 || true
    stopped=true
    ok "PM2 进程已停止（resume-backend / resume-frontend）"
  fi
  # 停 compose
  if has_compose && (have docker-compose || have docker compose); then
    info "停止 compose 服务..."
    compose_down
    stopped=true
    ok "compose 服务已停止"
  fi
  $stopped || info "未发现运行中的本脚本管理的进程"
}

action_status() {
  echo "---- 状态 ----"
  if have pm2; then
    pm2 status || true
  else
    echo "(PM2 未安装)"
  fi
  if [[ -f "$pid_file_dev" ]]; then
    pid="$(cat "$pid_file_dev")"
    if ps -p "$pid" >/dev/null 2>&1; then
      echo "开发：运行中 (PID $pid)"
    else
      echo "开发：记录存在但进程未运行"
    fi
  else
    echo "开发：未启动"
  fi
  if [[ -f "$RUNTIME_DIR/${APP_NAME}_prod.pid" ]]; then
    p="$(cat "$RUNTIME_DIR/${APP_NAME}_prod.pid")"
    if ps -p "$p" >/dev/null 2>&1; then
      echo "生产：运行中 (PID $p)"
    else
      echo "生产：记录存在但进程未运行"
    fi
  else
    if has_compose && have docker; then
      echo "生产（compose）："
      if have docker-compose; then docker-compose ps || true; else docker compose ps || true; fi
    else
      echo "生产：由 PM2 托管（见上表）或未启动"
    fi
  fi
}

action_logs() {
  echo "---- 日志 ----"
  if have pm2; then
    echo "[PM2] 查看实时日志： pm2 logs"
    pm2 logs --lines 50 || true
  else
    echo "(PM2 未安装，展示 nohup/compose 日志)"
    [[ -f "$log_dev" ]] && echo "[dev] $log_dev:" && tail -n 50 "$log_dev" || echo "暂无开发日志"
    if [[ -f "$RUNTIME_DIR/${APP_NAME}_prod.log" ]]; then
      echo "[prod] $RUNTIME_DIR/${APP_NAME}_prod.log:"
      tail -n 50 "$RUNTIME_DIR/${APP_NAME}_prod.log"
    elif has_compose && have docker; then
      echo "[compose] 最近 100 行："
      if have docker-compose; then docker-compose logs --tail=100 || true; else docker compose logs --tail=100 || true; fi
    else
      echo "暂无生产日志"
    fi
  fi
}

action_uninstall() {
  read -r -p "此操作会删除 node_modules、.venv、构建产物与运行时文件，继续？(y/N) " yn
  case "$yn" in
    [Yy]*)
      info "开始清理..."
      # 停 PM2
      if have pm2; then
        pm2 delete resume-backend  >/dev/null 2>&1 || true
        pm2 delete resume-frontend >/dev/null 2>&1 || true
        pm2 save >/dev/null 2>&1 || true
      fi
      rm -rf node_modules package-lock.json "$RUNTIME_DIR" ecosystem.config.js
      [[ -d apps/frontend ]] && (cd apps/frontend && rm -rf node_modules package-lock.json dist .next)
      [[ -d apps/backend  ]] && (cd apps/backend  && rm -rf .venv __pycache__)
      if has_compose && have docker; then
        info "清理 compose 容器/网络（如存在）..."
        if have docker-compose; then docker-compose down -v || true; else docker compose down -v || true; fi
      fi
      ok "清理完成"
      ;;
    *) info "已取消";;
  esac
}

action_set_mirrors() {
  echo "当前镜像："
  echo "  1) npm：$NPM_REGISTRY_DEFAULT"
  echo "  2) pip：$PIP_INDEX_DEFAULT"
  read -r -p "输入新的 npm 镜像（留空不变）：" nmr
  read -r -p "输入新的 pip 镜像（留空不变）：" pmi
  [[ -n "${nmr:-}" ]] && NPM_REGISTRY_DEFAULT="$nmr"
  [[ -n "${pmi:-}" ]] && PIP_INDEX_DEFAULT="$pmi" && UV_INDEX_DEFAULT="$pmi"
  read -r -p "是否持久化到本机配置（npm config / ~/.pip/pip.conf）？(y/N) " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    npm config set registry "$NPM_REGISTRY_DEFAULT"
    mkdir -p "$HOME/.pip"
    cat >"$HOME/.pip/pip.conf" <<EOF
[global]
index-url = ${PIP_INDEX_DEFAULT}
EOF
    ok "镜像已持久化"
  fi
  persist_conf
}

action_set_proxy() {
  echo "当前代理：HTTP=${HTTP_PROXY_DEFAULT:-none}  HTTPS=${HTTPS_PROXY_DEFAULT:-none}"
  read -r -p "设置 HTTP 代理（例：http://127.0.0.1:7890，留空清空）：" hp
  read -r -p "设置 HTTPS 代理（例：http://127.0.0.1:7890，留空清空）：" hsp
  HTTP_PROXY_DEFAULT="${hp:-}"
  HTTPS_PROXY_DEFAULT="${hsp:-}"
  persist_conf
  ok "代理已更新（执行动作时自动生效）"
}

press_enter() { read -r -p "按回车键返回菜单..." _; }

# ========================= 菜单循环 =========================
while true; do
  clear
  echo "=========== $APP_NAME 一键部署 ==========="
  echo "1) 安装/初始化"
  echo "2) 更新"
  echo "3) 仅构建（根目录 npm run build）"
  echo "4) 启动（开发模式）"
  echo "5) 启动（生产模式）"
  echo "6) 停止（开发/生产/PM2/compose）"
  echo "7) 查看状态"
  echo "8) 查看日志（优先PM2）"
  echo "9) 卸载/清理"
  echo "10) 镜像设置（npm/pip，支持持久化）"
  echo "11) 代理设置（HTTP/HTTPS）"
  echo "12) 安装PDF解析环境"
  echo "13) 退出"
  echo "========================================="
  read -r -p "请输入选项编号： " choice
  case "$choice" in
    1)  action_install;         press_enter;;
    2)  action_update;          press_enter;;
    3)  action_build_root;      press_enter;;
    4)  action_start_dev;       press_enter;;
    5)  action_start_prod;      press_enter;;
    6)  action_stop;            press_enter;;
    7)  action_status;          press_enter;;
    8)  action_logs;            press_enter;;
    9)  action_uninstall;       press_enter;;
    10) action_set_mirrors;     press_enter;;
    11) action_set_proxy;       press_enter;;
    12) action_install_pdf_env; press_enter;;
    13) echo "Bye~"; exit 0;;
    *) echo "无效选项"; sleep 1;;
  esac
done
