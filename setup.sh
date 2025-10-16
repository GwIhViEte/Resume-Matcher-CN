#!/usr/bin/env bash
# setup.sh - Resume Matcher 安装助手（Bash 版本）
set -euo pipefail
IFS=$'\n\t'

export PYTHONDONTWRITEBYTECODE=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export PATH="$HOME/.local/bin:$PATH"

DEV_PID_FILE="$SCRIPT_DIR/.devserver.pid"
DEV_LOG_FILE="$SCRIPT_DIR/.devserver.log"

INTERFACE_LOCALE="global"
CURRENT_PROFILE="auto"
NPM_REGISTRY="https://registry.npmjs.org"
PIP_INDEX="https://pypi.org/simple"
UV_INDEX="$PIP_INDEX"
REQUESTED_PROFILE=""
START_DEV_AFTER_INSTALL=0

if [[ "${LANG:-}" == zh* ]]; then
  INTERFACE_LOCALE="china"
fi

info() { printf 'ℹ️  %s\n' "$*"; }
success() { printf '✅ %s\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*"; }
error_exit() { printf '❌ %s\n' "$*" >&2; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

loc() {
  local zh="$1"
  local en="$2"
  if [[ "$INTERFACE_LOCALE" == "china" ]]; then
    printf '%s' "$zh"
  else
    printf '%s' "$en"
  fi
}

refresh_screen() {
  if command -v clear >/dev/null 2>&1; then
    clear
  else
    printf '\n'
  fi
}

print_help() {
  cat <<EOF
$(loc '用法: ./setup.sh [--help] [--profile auto|china|global] [--start-dev]' 'Usage: ./setup.sh [--help] [--profile auto|china|global] [--start-dev]')
  --help         $(loc '显示本帮助并退出' 'Show this help and exit')
  --profile MODE $(loc '指定网络模式: auto(自动), china(国内镜像), global(官方源)' 'Choose network mode: auto (auto-detect), china (mirrors), global (official)')
  --start-dev    $(loc '依赖安装完成后立即执行 npm run dev' 'Run npm run dev after installation')
$(loc '不带参数运行将进入交互式菜单。' 'Run without arguments to open the interactive menu.')
EOF
}

select_language() {
  while true; do
    refresh_screen
    printf "\n%s\n" "$(loc '请选择脚本显示语言 / Select interface language' 'Select interface language / 请选择脚本显示语言')"
    printf "1) %s\n" "$(loc '简体中文' 'Simplified Chinese')"
    printf "2) %s\n" "$(loc 'English' 'English')"
    local choice
    read -r -p ">> " choice
    case "$choice" in
      1)
        INTERFACE_LOCALE="china"
        refresh_screen
        return
        ;;
      2)
        INTERFACE_LOCALE="global"
        refresh_screen
        return
        ;;
      *)
        warn "$(loc '无效选项，请重新输入' 'Invalid option, please try again')"
        ;;
    esac
  done
}

pause_for_menu() {
  read -r -p "$(loc '按回车返回菜单' 'Press Enter to return to menu')" _
}

confirm_action() {
  local question_cn="$1"
  local question_en="$2"
  local default_choice="${3:-}"
  local answer
  local prompt_cn="$question_cn (Y/N)"
  local prompt_en="$question_en (Y/N)"

  if [[ -n "$default_choice" ]]; then
    local default_up="${default_choice^^}"
    case "$default_up" in
      Y|YES)
        prompt_cn="$question_cn (Y/n)"
        prompt_en="$question_en (Y/n)"
        default_choice="Y"
        ;;
      N|NO)
        prompt_cn="$question_cn (y/N)"
        prompt_en="$question_en (y/N)"
        default_choice="N"
        ;;
      *)
        warn "$(loc 'confirm_action 默认值无效，已忽略' 'Invalid default for confirm_action, ignoring')"
        default_choice=""
        ;;
    esac
  fi

  while true; do
    if [[ "$INTERFACE_LOCALE" == "china" ]]; then
      read -r -p "$prompt_cn: " answer
    else
      read -r -p "$prompt_en: " answer
    fi

    if [[ -z "$answer" && -n "$default_choice" ]]; then
      answer="$default_choice"
    fi

    [[ -z "$answer" ]] && continue
    answer="${answer^^}"
    case "$answer" in
      Y|YES|是|S) return 0 ;;
      N|NO|否) return 1 ;;
      *) warn "$(loc '请输入 Y 或 N' 'Please enter Y or N')" ;;
    esac
  done
}

run_with_progress() {
  local message_cn="$1"
  local message_en="$2"
  shift 2
  local message="$(loc "$message_cn" "$message_en")"
  info "$message"
  (
    local frames=('⠋' '⠙' '⠚' '⠞' '⠖' '⠦' '⠴' '⠲' '⠳' '⠓')
    local i=0
    while true; do
      printf '\r%s %s' "${frames[i]}" "$(loc '请稍候...' 'Please wait...')" >&2
      ((i = (i + 1) % ${#frames[@]}))
      sleep 0.2
    done
  ) &
  local spinner_pid=$!
  set +e
  "$@"
  local status=$?
  set -e
  kill "$spinner_pid" >/dev/null 2>&1 || true
  wait "$spinner_pid" 2>/dev/null || true
  printf '\r\033[K' >&2
  return $status
}

wait_for_ports() {
  local timeout="${1:-60}"
  shift
  local ports=("$@")
  if (( ${#ports[@]} == 0 )); then
    return 0
  fi
  local py
  if ! py="$(find_python)"; then
    return 0
  fi
  local start_ts
  start_ts="$(date +%s)"
  while true; do
    local all_up=1
    local port
    for port in "${ports[@]}"; do
      if ! "$py" - "$port" <<'PY'
import socket
import sys

port = int(sys.argv[1])
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.settimeout(1)
    if sock.connect_ex(("127.0.0.1", port)) == 0:
        raise SystemExit(0)
raise SystemExit(1)
PY
      then
        all_up=0
        break
      fi
    done
    if (( all_up == 1 )); then
      return 0
    fi
    if (( $(date +%s) - start_ts >= timeout )); then
      return 1
    fi
    sleep 2
  done
}

acquire_dev_lock() {
  if command_exists flock; then
    exec {DEV_LOCK_FD}>"$DEV_PID_FILE.lock"
    flock "$DEV_LOCK_FD"
  fi
}

release_dev_lock() {
  if [[ -n "${DEV_LOCK_FD:-}" ]]; then
    flock -u "$DEV_LOCK_FD" 2>/dev/null || true
    exec {DEV_LOCK_FD}>&-
    unset DEV_LOCK_FD
    rm -f "$DEV_PID_FILE.lock"
  fi
}

resolve_repo_path() {
  local target="$1"
  local py_cmd="${PY_CMD:-}"
  if [[ -z "$py_cmd" ]]; then
    if ! py_cmd="$(find_python)"; then
      return 1
    fi
  fi
  TARGET_PATH="$target" "$py_cmd" - "$SCRIPT_DIR" <<'PY'
import os
import sys

script_dir = os.path.abspath(sys.argv[1])
target = os.environ.get("TARGET_PATH", "")

if not target:
    raise SystemExit(1)

if not os.path.isabs(target):
    target = os.path.join(script_dir, target)

normalized = os.path.abspath(target)
try:
    common = os.path.commonpath([script_dir, normalized])
except ValueError:
    raise SystemExit(2)

if common != script_dir:
    raise SystemExit(2)

print(normalized)
PY
}

ensure_app_env() {
  local app_name="$1"
  local label="$2"
  local dir="$SCRIPT_DIR/apps/$app_name"
  local path="$dir/.env"
  local sample="$dir/.env.sample"
  if [[ ! -d "$dir" ]]; then
    warn "$(printf "$(loc '%s 目录不存在，跳过 .env 确认' '%s directory missing, skipping .env check')" "$dir")"
    echo "$path"
    return
  fi
  ensure_env_file "$sample" "$path" "$label"
  echo "$path"
}

test_endpoint() {
  local url="$1"
  if curl -fsS --connect-timeout 5 --max-time 10 -o /dev/null "$url"; then
    return 0
  fi
  return 1
}

resolve_network_profile() {
  local requested="${1:-auto}"
  case "$requested" in
    china)
      info "$(printf "$(loc '已选择网络模式：%s' 'Using forced network profile: %s')" "china")"
      echo "china"
      ;;
    global)
      info "$(printf "$(loc '已选择网络模式：%s' 'Using forced network profile: %s')" "global")"
      echo "global"
      ;;
    *)
      info "$(loc '正在自动探测网络可达性...' 'Auto-detecting network connectivity...')"
      local endpoints=(
        "TUNA PyPI|https://pypi.tuna.tsinghua.edu.cn/simple"
        "npmmirror|https://registry.npmmirror.com"
      )
      local all_reachable=1
      local entry name url status
      for entry in "${endpoints[@]}"; do
        name="${entry%%|*}"
        url="${entry#*|}"
        if test_endpoint "$url"; then
          status="$(loc '可达' 'reachable')"
        else
          status="$(loc '不可达' 'unreachable')"
          all_reachable=0
        fi
        info "$(printf "$(loc '探测 %s (%s) => %s' 'Probe %s (%s) => %s')" "$name" "$url" "$status")"
      done
      if (( all_reachable == 1 )); then
        info "$(printf "$(loc '自动判定为：%s 模式（可在菜单覆盖）' 'Auto-detect result: %s profile (override via menu)')" "china")"
        echo "china"
      else
        info "$(printf "$(loc '自动判定为：%s 模式（可在菜单覆盖）' 'Auto-detect result: %s profile (override via menu)')" "global")"
        echo "global"
      fi
      ;;
  esac
}

apply_mirrors() {
  local profile="$1"
  CURRENT_PROFILE="$profile"
  if [[ "$profile" == "china" ]]; then
    NPM_REGISTRY="https://registry.npmmirror.com"
    PIP_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple"
  else
    NPM_REGISTRY="https://registry.npmjs.org"
    PIP_INDEX="https://pypi.org/simple"
  fi
  UV_INDEX="$PIP_INDEX"
  export NPM_CONFIG_REGISTRY="$NPM_REGISTRY"
  export PIP_INDEX_URL="$PIP_INDEX"
  export UV_INDEX_URL="$UV_INDEX"
  info "$(printf "$(loc '当前使用的源 -> npm: %s，PyPI: %s' 'Active registries -> npm: %s, PyPI: %s')" "$NPM_REGISTRY" "$PIP_INDEX")"
}

find_python() {
  if command_exists "python3"; then
    echo "python3"
  elif command_exists "python"; then
    echo "python"
  else
    return 1
  fi
}

find_pip() {
  if command_exists "pip3"; then
    echo "pip3"
  elif command_exists "pip"; then
    echo "pip"
  else
    return 1
  fi
}

install_uv_if_missing() {
  if command_exists "uv"; then
    success "$(loc 'uv 检测通过' 'uv detected')"
    return
  fi

  info "$(loc '未检测到 uv，尝试自动安装...' 'uv not found. Attempting automatic installation...')"
  local urls=()
  if [[ "$CURRENT_PROFILE" == "china" ]]; then
    urls=(
      "https://mirror.ghproxy.com/https://astral.sh/uv/install.sh"
      "https://ghproxy.com/https://astral.sh/uv/install.sh"
      "https://astral.sh/uv/install.sh"
    )
  else
    urls=("https://astral.sh/uv/install.sh")
  fi

  local tmp
  tmp="$(mktemp)"
  local installed=0
  local url
  for url in "${urls[@]}"; do
    info "$(printf "$(loc '下载安装脚本：%s' 'Downloading installer: %s')" "$url")"
    if curl -fsSL "$url" -o "$tmp"; then
      if sh "$tmp" >/dev/null 2>&1; then
        installed=1
        break
      fi
    fi
    warn "$(printf "$(loc '安装脚本失败：%s' 'Installer failed: %s')" "$url")"
  done
  rm -f "$tmp"

  export PATH="$HOME/.local/bin:$PATH"

  if ! command_exists "uv"; then
    if (( installed == 1 )); then
      error_exit "$(loc 'uv 安装失败，请参考 https://docs.astral.sh/uv/' 'uv installation failed. Please install manually: https://docs.astral.sh/uv/')"
    else
      error_exit "$(loc '无法获取 uv 安装脚本，请手动安装' 'Unable to download uv installer. Please install manually.')"
    fi
  fi

  success "$(loc 'uv 检测通过' 'uv detected')"
}

remove_bom() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    return
  fi
  local py
  if ! py="$(find_python)"; then
    return
  fi
  "$py" - "$file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    sys.exit(0)
data = path.read_bytes()
if data.startswith(b"\xef\xbb\xbf"):
    path.write_bytes(data[3:])
PY
}

ensure_env_file() {
  local sample="$1"
  local target="$2"
  local label="$3"
  if [[ -f "$sample" && ! -f "$target" ]]; then
    info "$(printf "$(loc '复制 %s -> %s' 'Copy %s -> %s')" "$sample" "$target")"
    cp "$sample" "$target"
    success "$(printf "$(loc '%s 已创建，请填写必要配置' '%s created. Please fill required secrets')" "$label")"
  elif [[ -f "$target" ]]; then
    info "$(printf "$(loc '%s 已存在' '%s already exists')" "$label")"
  else
    touch "$target"
    success "$(printf "$(loc '%s 已创建，请填写必要配置' '%s created. Please fill required secrets')" "$label")"
  fi
  remove_bom "$target"
}

ensure_backend_env() {
  ensure_app_env "backend" "backend .env"
}

ensure_frontend_env() {
  ensure_app_env "frontend" "frontend .env"
}

set_env_entry() {
  local file="$1"
  local key="$2"
  local value="$3"
  if [[ -z "${file:-}" ]]; then
    error_exit "$(loc 'set_env_entry 缺少文件路径' 'set_env_entry missing target file path')"
  fi
  if [[ -z "${key:-}" ]]; then
    error_exit "$(loc 'set_env_entry 缺少键名' 'set_env_entry missing key name')"
  fi
  if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    error_exit "$(printf "$(loc '非法的环境变量键名：%s' 'Invalid environment variable key: %s')" "$key")"
  fi
  local py
  if ! py="$(find_python)"; then
    error_exit "$(loc '未检测到 Python 3，请先安装' 'Python 3 not found. Please install Python 3.')"
  fi
  local normalized
  if ! normalized="$(PY_CMD="$py" resolve_repo_path "$file")"; then
    local resolve_status=$?
    if (( resolve_status == 2 )); then
      error_exit "$(printf "$(loc '拒绝访问仓库外部路径：%s' 'Refusing to touch path outside repository: %s')" "$file")"
    else
      error_exit "$(printf "$(loc '无法解析路径：%s' 'Unable to resolve target path: %s')" "$file")"
    fi
  fi
  mkdir -p "$(dirname "$normalized")"
  remove_bom "$normalized"
  if ! "$py" - "$normalized" "$key" "$value" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]

try:
    if not path.exists():
        path.touch()

    text = path.read_text(encoding="utf-8") if path.stat().st_size else ""
    lines = text.splitlines()

    def escape_env_value(raw: str) -> str:
        """Escape characters that are unsafe for .env double quoted values."""
        return (
            raw.replace("\\", "\\\\")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace('"', '\\"')
        )

    formatted = f'{key}="{escape_env_value(value)}"'

    for idx, line in enumerate(lines):
        if line.strip().startswith(f"{key}="):
            lines[idx] = formatted
            break
    else:
        lines.append(formatted)

    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
except Exception as exc:  # noqa: BLE001
    raise SystemExit(f"failed to update env entry: {exc}")
PY
  then
    error_exit "$(printf "$(loc '写入键 %s 到 %s 失败' 'Failed to write key %s into %s')" "$key" "$normalized")"
  fi
}

install_dependencies() {
  local requested="${1:-auto}"
  local start_dev="${2:-0}"

  info "$(loc '开始运行 Resume Matcher 安装流程...' 'Starting Resume Matcher setup...')"
  local profile
  profile="$(resolve_network_profile "$requested")"
  apply_mirrors "$profile"

  if ! command_exists "node"; then
    error_exit "$(loc '未检测到 Node.js，请先安装 Node.js v18+' 'Node.js not found. Please install Node.js v18+ first.')"
  fi
  local node_version
  node_version="$(node --version 2>/dev/null || node -v 2>/dev/null)"
  local node_major=""
  if [[ "$node_version" =~ ([0-9]+) ]]; then
    node_major="${BASH_REMATCH[1]}"
  fi
  if [[ -z "$node_major" ]]; then
    error_exit "$(printf "$(loc '无法解析 Node.js 版本号：%s' 'Unable to parse Node.js version: %s')" "$node_version")"
  fi
  if (( node_major < 18 )); then
    error_exit "$(printf "$(loc 'Node.js 版本 %s 过低，需要 v18+' 'Node.js version %s is too old. v18+ required.')" "$node_version")"
  fi
  success "$(printf "$(loc 'Node.js %s 检测通过' 'Node.js %s detected')" "$node_version")"

  if ! command_exists "npm"; then
    error_exit "$(loc '未检测到 npm，请安装后重试' 'npm not found. Please install npm and retry.')"
  fi
  success "$(printf "$(loc 'npm 检测通过（源 %s）' 'npm detected (registry %s)')" "$NPM_REGISTRY")"

  local python_cmd
  if ! python_cmd="$(find_python)"; then
    error_exit "$(loc '未检测到 Python 3，请先安装' 'Python 3 not found. Please install Python 3.')"
  fi
  success "$(printf "$(loc 'Python 检测通过，执行命令：%s' 'Python detected via %s')" "$python_cmd")"

  local pip_cmd
  if ! pip_cmd="$(find_pip)"; then
    error_exit "$(loc '未检测到 pip，请先安装' 'pip not found. Please install pip.')"
  fi
  success "$(printf "$(loc 'pip 检测通过（索引 %s）' 'pip detected (index %s)')" "$PIP_INDEX")"

  install_uv_if_missing

  ensure_env_file "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env" "root .env"

  if ! NPM_CONFIG_REGISTRY="$NPM_REGISTRY" run_with_progress "安装仓库级 npm 依赖..." "Installing workspace npm dependencies..." npm install; then
    error_exit "$(loc 'npm install 失败，请检查网络或 npm 日志' 'npm install failed. Please inspect your network settings or npm logs.')"
  fi
  success "$(loc 'npm install 完成' 'npm install completed')"

  if [[ -d "$SCRIPT_DIR/apps/backend" ]]; then
    ensure_env_file "$SCRIPT_DIR/apps/backend/.env.sample" "$SCRIPT_DIR/apps/backend/.env" "backend .env"
    (
      cd "$SCRIPT_DIR/apps/backend"
      if [[ ! -d ".venv" ]]; then
        if ! UV_INDEX_URL="$UV_INDEX" run_with_progress "创建 Python 虚拟环境（uv venv）..." "Creating Python virtual environment (uv venv)..." uv venv; then
          error_exit "$(loc 'uv venv 执行失败，请检查 uv 输出日志' 'uv venv failed. Please review uv output logs.')"
        fi
        success "$(loc 'uv venv 完成' 'uv venv completed')"
      fi
      if ! UV_INDEX_URL="$UV_INDEX" run_with_progress "$(printf "同步后端依赖（uv sync，PyPI 源 %s）..." "$PIP_INDEX")" "$(printf "Syncing backend dependencies (uv sync, index %s)..." "$PIP_INDEX")" uv sync; then
        error_exit "$(loc 'uv sync 执行失败，请检查 uv 输出日志' 'uv sync failed. Please review uv output logs.')"
      fi
      success "$(loc 'uv sync 完成' 'uv sync completed')"
    )
  fi

  if [[ -d "$SCRIPT_DIR/apps/frontend" ]]; then
    ensure_env_file "$SCRIPT_DIR/apps/frontend/.env.sample" "$SCRIPT_DIR/apps/frontend/.env" "frontend .env"
    (
      cd "$SCRIPT_DIR/apps/frontend"
      if ! NPM_CONFIG_REGISTRY="$NPM_REGISTRY" run_with_progress "安装前端依赖（npm install）..." "Installing frontend dependencies (npm install)..." npm install; then
        error_exit "$(loc '前端依赖安装失败，请查看 npm 输出日志' 'Frontend npm install failed. Please inspect npm output logs.')"
      fi
      success "$(loc '前端依赖安装完成' 'Frontend dependencies installed')"
    )
  fi

  success "$(loc '依赖安装完成' 'Dependency installation completed')"
  printf "%s\n" "$(loc '后续步骤：' 'Next steps:')"
  printf "%s\n" "$(loc '  1. 在各 .env 中填入所需的 API 凭据' '  1. Populate required API credentials in .env files')"
  printf "%s\n" "$(loc '  2. 运行 npm run dev 启动开发服务器' '  2. Run \"npm run dev\" to start development servers')"

  if [[ "$start_dev" == "1" ]]; then
    start_dev_servers
  fi
}

check_repository_updates() {
  if ! command_exists "git"; then
    warn "$(loc '未检测到 git，请先安装 Git。' 'git not found. Please install Git first.')"
    return
  fi

  if ! confirm_action "确认执行仓库更新检查？" "Run repository update check?"; then
    info "$(loc '已取消仓库更新检查' 'Update check cancelled')"
    return
  fi

  info "$(loc '同步远程仓库引用...' 'Fetching remote references...')"
  git fetch --all --prune
  success "$(loc '远程引用已更新' 'Remote references updated')"

  local branch
  branch="$(git rev-parse --abbrev-ref HEAD | tr -d '\r\n')"
  info "$(printf "$(loc '当前分支：%s' 'Current branch: %s')" "$branch")"

  printf "%s\n" "$(loc '--- git status -sb ---' '--- git status -sb ---')"
  git status -sb

  printf "%s\n" "$(printf "$(loc '--- 与 origin/%s 的最近差异 ---' '--- Recent commits from origin/%s ---')" "$branch")"
  git log --oneline --decorate --max-count 5 "HEAD..origin/$branch"
}

start_dev_servers() {
  ensure_env_file "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env" "root .env"
  acquire_dev_lock
  trap '[[ -n "$tmp_pid_file" && -f "$tmp_pid_file" ]] && rm -f "$tmp_pid_file"; release_dev_lock' RETURN
  local tmp_pid_file=""

  if [[ -f "$DEV_PID_FILE" ]]; then
    local existing_pid
    existing_pid="$(<"$DEV_PID_FILE")"
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" >/dev/null 2>&1; then
      info "$(printf "$(loc '开发服务器已在运行 (PID %s)' 'Dev servers already running (PID %s)')" "$existing_pid")"
      return
    else
      rm -f "$DEV_PID_FILE"
      warn "$(loc 'PID 信息无效，已清理记录' 'PID record invalid, cleaned up')"
    fi
  fi

  if [[ -f "$DEV_LOG_FILE" ]]; then
    local log_size
    log_size="$(wc -c <"$DEV_LOG_FILE" 2>/dev/null || echo 0)"
    if [[ -n "$log_size" ]] && (( log_size > 5242880 )); then
      local rotated="$DEV_LOG_FILE.$(date +%Y%m%d%H%M%S)"
      mv "$DEV_LOG_FILE" "$rotated"
      info "$(printf "$(loc '日志已轮换为 %s' 'Rotated dev log to %s')" "$rotated")"
    fi
  fi
  : > "$DEV_LOG_FILE"

  tmp_pid_file="$DEV_PID_FILE.tmp$$"
  (
    cd "$SCRIPT_DIR"
    if command_exists "setsid"; then
      nohup setsid npm run dev >>"$DEV_LOG_FILE" 2>&1 &
    else
      nohup npm run dev >>"$DEV_LOG_FILE" 2>&1 &
    fi
    local dev_pid=$!
    disown "$dev_pid" 2>/dev/null || true
    printf '%s\n' "$dev_pid" >"$tmp_pid_file"
  )

  if [[ ! -f "$tmp_pid_file" ]]; then
    warn "$(loc '未能写入 PID 文件，请检查 npm run dev 输出' 'Failed to write PID file. Check npm run dev output')"
    return
  fi

  mv "$tmp_pid_file" "$DEV_PID_FILE"
  tmp_pid_file=""
  local pid
  pid="$(<"$DEV_PID_FILE")"
  if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    info "$(printf "$(loc '日志输出保存至 %s' 'Logs written to %s')" "$DEV_LOG_FILE")"
    if wait_for_ports 60 3000 8000; then
      success "$(printf "$(loc '已在后台启动开发服务器 (PID %s)' 'Started dev servers in background (PID %s)')" "$pid")"
    else
      warn "$(printf "$(loc 'PID %s 已启动，但未检测到预期端口开放，请检查日志' 'Process %s started, but expected ports did not open in time. Check the log.')" "$pid")"
    fi
  else
    rm -f "$DEV_PID_FILE"
    warn "$(loc '启动开发服务器失败，请检查 npm run dev 输出' 'Failed to start dev servers. Check npm run dev output')"
  fi
}

stop_dev_servers() {
  acquire_dev_lock
  trap 'release_dev_lock' RETURN

  if [[ ! -f "$DEV_PID_FILE" ]]; then
    info "$(loc '未记录正在运行的开发服务器' 'No recorded dev server to stop')"
    return
  fi

  local pid
  pid="$(<"$DEV_PID_FILE")"
  if [[ -z "$pid" ]]; then
    rm -f "$DEV_PID_FILE"
    warn "$(loc 'PID 信息无效，已清理记录' 'PID record invalid, cleaned up')"
    return
  fi

  if ! kill -0 "$pid" >/dev/null 2>&1; then
    rm -f "$DEV_PID_FILE"
    warn "$(loc 'PID 信息无效，已清理记录' 'PID record invalid, cleaned up')"
    return
  fi

  if ! kill "$pid" >/dev/null 2>&1; then
    warn "$(printf "$(loc '停止开发服务器时出现问题：%s' 'Failed to stop dev servers: %s')" "PID $pid")"
    return
  fi

  local waited=0
  local timeout=10
  while kill -0 "$pid" >/dev/null 2>&1 && (( waited < timeout )); do
    sleep 1
    ((waited++))
  done

  if kill -0 "$pid" >/dev/null 2>&1; then
    warn "$(printf "$(loc '进程 %s 未按时退出，发送 SIGKILL' 'Process %s did not exit in time. Sending SIGKILL.')" "$pid")"
    kill -9 "$pid" >/dev/null 2>&1 || true
  else
    success "$(printf "$(loc '已停止开发服务器 (PID %s)' 'Stopped dev servers (PID %s)')" "$pid")"
  fi

  rm -f "$DEV_PID_FILE"
}

uninstall_dependencies() {
  local targets=(
    "$SCRIPT_DIR/node_modules"
    "$SCRIPT_DIR/apps/frontend/node_modules"
    "$SCRIPT_DIR/apps/backend/.venv"
  )
  local existing=()
  local target
  for target in "${targets[@]}"; do
    if [[ -e "$target" ]]; then
      existing+=("$target")
    fi
  done

  if (( ${#existing[@]} == 0 )); then
    info "$(loc '未找到需要清理的依赖目录' 'No dependency directories found to remove')"
    return
  fi

  info "$(loc '以下目录将被删除：' 'The following directories will be removed:')"
  for target in "${existing[@]}"; do
    printf "  - %s\n" "$target"
  done

  local confirm
  read -r -p "$(loc '请输入 YES 确认删除： ' 'Type YES to proceed: ')" confirm
  if [[ "${confirm^^}" != "YES" ]]; then
    info "$(loc '已取消卸载操作' 'Uninstall operation cancelled')"
    return
  fi

  for target in "${existing[@]}"; do
    if rm -rf "$target"; then
      success "$(printf "$(loc '已删除 %s' 'Removed %s')" "$target")"
    else
      warn "$(printf "$(loc '删除 %s 时出现问题' 'Failed to remove %s')" "$target")"
    fi
  done

  success "$(loc '卸载流程完成' 'Cleanup completed')"
}

configure_ollama() {
  local backend_env
  backend_env="$(ensure_backend_env)"
  local frontend_env
  frontend_env="$(ensure_frontend_env)"

  local default_ll="gemma3:4b"
  local default_embed="nomic-embed-text:latest"
  local ll_input
  local embed_input
  if [[ "$INTERFACE_LOCALE" == "china" ]]; then
    read -r -p "请输入对话模型名称 (默认 ${default_ll}): " ll_input
    read -r -p "请输入向量模型名称 (默认 ${default_embed}): " embed_input
  else
    read -r -p "Enter chat model name (default ${default_ll}): " ll_input
    read -r -p "Enter embedding model name (default ${default_embed}): " embed_input
  fi
  [[ -z "$ll_input" ]] && ll_input="$default_ll"
  [[ -z "$embed_input" ]] && embed_input="$default_embed"

  set_env_entry "$backend_env" "LLM_PROVIDER" "ollama"
  set_env_entry "$backend_env" "LLM_BASE_URL" "http://127.0.0.1:11434"
  set_env_entry "$backend_env" "LLM_API_KEY" ""
  set_env_entry "$backend_env" "LL_MODEL" "$ll_input"
  set_env_entry "$backend_env" "EMBEDDING_PROVIDER" "ollama"
  set_env_entry "$backend_env" "EMBEDDING_BASE_URL" "http://127.0.0.1:11434"
  set_env_entry "$backend_env" "EMBEDDING_API_KEY" ""
  set_env_entry "$backend_env" "EMBEDDING_MODEL" "$embed_input"

  set_env_entry "$frontend_env" "NEXT_PUBLIC_LLM_PROVIDER" "ollama"
  set_env_entry "$frontend_env" "NEXT_PUBLIC_DEFAULT_MODEL" "$ll_input"
  set_env_entry "$frontend_env" "NEXT_PUBLIC_MODEL_SELECTION" "disabled"

  success "$(loc '已切换为本地 Ollama 配置' 'Switched to local Ollama configuration')"
}

configure_api() {
  local backend_env
  backend_env="$(ensure_backend_env)"
  local frontend_env
  frontend_env="$(ensure_frontend_env)"

  local default_provider="openai"
  local default_base="https://api.openai.com/v1"
  local default_ll="gpt-4.1"
  local default_embed="text-embedding-3-large"

  local provider_input
  local base_input
  local ll_input
  local embed_input
  local api_key_input

  if [[ "$INTERFACE_LOCALE" == "china" ]]; then
    read -r -p "请输入提供商标识 (默认 ${default_provider}): " provider_input
    read -r -p "请输入 API Base URL (默认 ${default_base}): " base_input
    read -r -p "请输入对话模型名称 (默认 ${default_ll}): " ll_input
    read -r -p "请输入向量模型名称 (默认 ${default_embed}): " embed_input
    read -r -p "请输入 API Key (回车保留现有值): " api_key_input
  else
    read -r -p "Enter provider identifier (default ${default_provider}): " provider_input
    read -r -p "Enter API base URL (default ${default_base}): " base_input
    read -r -p "Enter chat model name (default ${default_ll}): " ll_input
    read -r -p "Enter embedding model name (default ${default_embed}): " embed_input
    read -r -p "Enter API Key (press Enter to keep current): " api_key_input
  fi

  [[ -z "$provider_input" ]] && provider_input="$default_provider"
  [[ -z "$base_input" ]] && base_input="$default_base"
  [[ -z "$ll_input" ]] && ll_input="$default_ll"
  [[ -z "$embed_input" ]] && embed_input="$default_embed"

  set_env_entry "$backend_env" "LLM_PROVIDER" "$provider_input"
  set_env_entry "$backend_env" "LLM_BASE_URL" "$base_input"
  set_env_entry "$backend_env" "LL_MODEL" "$ll_input"
  set_env_entry "$backend_env" "EMBEDDING_PROVIDER" "$provider_input"
  set_env_entry "$backend_env" "EMBEDDING_BASE_URL" "$base_input"
  set_env_entry "$backend_env" "EMBEDDING_MODEL" "$embed_input"

  if [[ -n "$api_key_input" ]]; then
    set_env_entry "$backend_env" "LLM_API_KEY" "$api_key_input"
    set_env_entry "$backend_env" "EMBEDDING_API_KEY" "$api_key_input"
  fi

  set_env_entry "$frontend_env" "NEXT_PUBLIC_LLM_PROVIDER" "$provider_input"
  set_env_entry "$frontend_env" "NEXT_PUBLIC_DEFAULT_MODEL" "$ll_input"
  set_env_entry "$frontend_env" "NEXT_PUBLIC_MODEL_SELECTION" "enabled"

  success "$(loc '已切换为远程 API 配置' 'Switched to remote API configuration')"
}

provider_menu() {
  refresh_screen
  printf "\n%s\n" "$(loc '=== 模型提供商设置 ===' '=== Model Provider Settings ===')"
  printf "%s\n" "$(loc '1) 使用本地 Ollama' '1) Use local Ollama')"
  printf "%s\n" "$(loc '2) 使用远程 API' '2) Use remote API')"
  printf "%s\n" "$(loc '0) 返回主菜单' '0) Return to main menu')"
  local choice
  read -r -p "$(loc '请选择操作：' 'Select an option: ') " choice
  case "$choice" in
    1) configure_ollama ;;
    2) configure_api ;;
    0) info "$(loc '已返回主菜单' 'Returning to main menu')" ;;
    *) warn "$(loc '无效选项，请重新输入' 'Invalid option, please try again')" ;;
  esac
  pause_for_menu
}

main_menu() {
  while true; do
    refresh_screen
    printf "\n%s\n" "$(loc '=== Resume Matcher 安装助手 ===' '=== Resume Matcher Setup Assistant ===')"
    printf "%s\n" "$(loc '1) 安装/修复依赖' '1) Install / Repair dependencies')"
    printf "%s\n" "$(loc '2) 检查仓库更新' '2) Check repository updates')"
    printf "%s\n" "$(loc '3) 更改模型提供商' '3) Change model provider')"
    printf "%s\n" "$(loc '4) 启动开发服务器' '4) Start dev servers')"
    printf "%s\n" "$(loc '5) 停止开发服务器' '5) Stop dev servers')"
    printf "%s\n" "$(loc '6) 卸载本地依赖' '6) Uninstall local dependencies')"
    printf "%s\n" "$(loc '0) 退出' '0) Exit')"
    local choice
    read -r -p "$(loc '请选择操作：' 'Select an option: ') " choice
    case "$choice" in
      1)
        local profile_input
        read -r -p "$(loc '选择网络模式 (auto/china/global，默认 auto)： ' 'Select network profile (auto/china/global, default auto): ')" profile_input
        [[ -z "$profile_input" ]] && profile_input="auto"
        install_dependencies "$profile_input" 0
        pause_for_menu
        ;;
      2)
        check_repository_updates
        pause_for_menu
        ;;
      3)
        provider_menu
        ;;
      4)
        start_dev_servers
        pause_for_menu
        ;;
      5)
        stop_dev_servers
        pause_for_menu
        ;;
      6)
        uninstall_dependencies
        pause_for_menu
        ;;
      0)
        break
        ;;
      *)
        warn "$(loc '无效选项，请重新输入' 'Invalid option, please try again')"
        pause_for_menu
        ;;
    esac
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --profile)
      shift || error_exit "$(loc '缺少 --profile 的取值' 'Missing value for --profile')"
      REQUESTED_PROFILE="$1"
      ;;
    --start-dev)
      START_DEV_AFTER_INSTALL=1
      ;;
    *)
      error_exit "$(printf "$(loc '未知参数：%s' 'Unknown option: %s')" "$1")"
      ;;
  esac
  shift
done

if [[ -n "$REQUESTED_PROFILE" ]]; then
  case "$REQUESTED_PROFILE" in
    auto|china|global) ;;
    *) error_exit "$(printf "$(loc '非法的网络模式：%s' 'Invalid profile: %s')" "$REQUESTED_PROFILE")" ;;
  esac
fi

if [[ -n "$REQUESTED_PROFILE" || $START_DEV_AFTER_INSTALL -eq 1 ]]; then
  profile_to_use="${REQUESTED_PROFILE:-auto}"
  install_dependencies "$profile_to_use" "$START_DEV_AFTER_INSTALL"
  exit 0
fi

select_language
main_menu
