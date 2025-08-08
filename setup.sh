#!/usr/bin/env bash
#
# setup.sh - Resume Matcher 初始化脚本 (OpenAI API 版本 / 中文提示 / 国内加速版)
#

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

# 检查命令
check_cmd() {
  local cmd=$1
  if ! command -v "$cmd" &> /dev/null; then
    error "未安装命令: $cmd，请先安装再运行此脚本。"
  fi
}

info "检测依赖..."
check_cmd node
check_cmd npm
check_cmd python3
check_cmd pip3

# 设置 npm 国内源
info "设置 npm 国内镜像..."
npm config set registry https://registry.npmmirror.com

# 设置 pip 国内源（全局配置）
PIP_CONF_DIR="$HOME/.pip"
mkdir -p $PIP_CONF_DIR
cat > $PIP_CONF_DIR/pip.conf <<EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
EOF
success "pip 已设置国内镜像"

# 安装 uv（如果没有）
if ! command -v uv &> /dev/null; then
  info "安装 uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

# 初始化根 .env
if [[ -f .env.example && ! -f .env ]]; then
  cp .env.example .env
  success "根目录 .env 创建完成，请填写 OPENAI_API_KEY"
fi

# 安装根依赖（加速）
info "安装根依赖 (npm ci 加速版)..."
npm ci --registry=https://registry.npmmirror.com
success "根依赖安装完成"

# 后端
info "安装后端依赖..."
(
  cd apps/backend
  if [[ -f .env.sample && ! -f .env ]]; then
    cp .env.sample .env
    success "后端 .env 创建完成"
  fi
  uv pip install -e . --index-url https://pypi.tuna.tsinghua.edu.cn/simple
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
  npm ci --registry=https://registry.npmmirror.com
  success "前端依赖安装完成"
)

success "🎉 环境初始化完成！"
