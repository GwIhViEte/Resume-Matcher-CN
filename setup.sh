#!/usr/bin/env bash
# setup.sh - Resume Matcher 初始化脚本
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
IFS=$'\n\t'

OS="$(uname -s)"
case "$OS" in
  Linux*)   OS_TYPE="Linux" ;;
  Darwin*)  OS_TYPE="macOS" ;;
  *)        OS_TYPE="$OS" ;;
esac

info()    { echo -e "ℹ  $*"; }
success() { echo -e "✅ $*"; }
error()   { echo -e "❌ $*" >&2; exit 1; }
have()    { command -v "$1" >/dev/null 2>&1; }

# 检查命令
info "检测依赖..."
for c in node npm python3 pip3; do
  have "$c" || error "未安装命令: $c，请先安装再运行此脚本。"
done

# 设置 npm 国内源
info "设置 npm 国内镜像..."
npm config set registry https://registry.npmmirror.com

# 设置 pip 国内源（全局配置）
PIP_CONF_DIR="$HOME/.pip"
mkdir -p "$PIP_CONF_DIR"
cat > "$PIP_CONF_DIR/pip.conf" <<EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
EOF
success "pip 已设置国内镜像"

# 安装 uv（如果没有）
if ! have uv; then
  info "安装 uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

# Linux：安装 PDF 系统依赖（可选但推荐）
if [[ "$OS_TYPE" == "Linux" ]]; then
  info "安装 PDF 解析系统依赖（poppler/tesseract/imagemagick/ghostscript/中文字体）..."
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -y
  sudo apt-get install -y \
    poppler-utils ghostscript imagemagick \
    tesseract-ocr libtesseract-dev tesseract-ocr-chi-sim tesseract-ocr-chi-tra \
    fontconfig fonts-noto-cjk libcairo2 libpango-1.0-0 libxml2 || true

  # 调整 ImageMagick policy：允许 PDF/PS/EPS 只读
  for f in /etc/ImageMagick-6/policy.xml /etc/ImageMagick-7/policy.xml; do
    if [[ -f "$f" ]]; then
      sudo cp -a "$f" "${f}.bak" || true
      sudo sed -i \
        -e 's#<policy domain="coder" rights="none" pattern="PDF" />#<policy domain="coder" rights="read" pattern="PDF" />#g' \
        -e 's#<policy domain="coder" rights="none" pattern="PS" />#<policy domain="coder" rights="read" pattern="PS" />#g' \
        -e 's#<policy domain="coder" rights="none" pattern="EPS" />#<policy domain="coder" rights="read" pattern="EPS" />#g' \
        "$f" || true
    fi
  done
  success "PDF 系统依赖与 policy 调整完成"
fi

# 初始化根 .env
if [[ -f .env.example && ! -f .env ]]; then
  cp .env.example .env
  success "根目录 .env 创建完成，请填写 OPENAI_API_KEY"
fi

# 安装根依赖（忽略 install 脚本，避免触发子项目二次安装）
info "安装根依赖 (npm ci/install 加速版)..."
if [[ -f package-lock.json ]]; then
  npm ci --no-fund --no-audit --ignore-scripts --registry=https://registry.npmmirror.com
else
  npm install --no-fund --no-audit --ignore-scripts --registry=https://registry.npmmirror.com
fi
success "根依赖安装完成"

# 后端
info "安装后端依赖..."
(
  cd apps/backend
  if [[ -f .env.sample && ! -f .env ]]; then
    cp .env.sample .env
    success "后端 .env 创建完成"
  fi
  [[ -d .venv ]] || uv venv
  # shellcheck disable=SC1091
  source .venv/bin/activate
  # 项目依赖
  if [[ -f pyproject.toml ]]; then
    uv pip install -e . --index-url https://pypi.tuna.tsinghua.edu.cn/simple
  fi
  # 兜底补齐 PDF 常用包（已装会快速跳过）
  uv pip install pdfplumber pdfminer.six pymupdf pillow pytesseract
  success "后端依赖安装完成"
)

# 前端
info "安装前端依赖..."
(
  cd apps/frontend
  if [[ -f .env.sample && ! -f .env ]]; then
    cp .env.sample .env
    success "前端 .env 创建完成"
  fi
  if [[ -f package-lock.json ]]; then
    npm ci --no-fund --no-audit --prefer-offline --progress=false --registry=https://registry.npmmirror.com
  else
    npm install --no-fund --no-audit --prefer-offline --progress=false --registry=https://registry.npmmirror.com
  fi
  success "前端依赖安装完成"
)

# 可选：构建
if grep -q '"build"\s*:' package.json 2>/dev/null; then
  info "构建项目 (npm run build)..."
  CI=1 NEXT_TELEMETRY_DISABLED=1 npm run build </dev/null
  success "项目构建完成"
fi

success "🎉 环境初始化完成！"
