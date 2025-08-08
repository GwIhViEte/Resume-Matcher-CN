#!/usr/bin/env bash
#
# setup.sh - Resume Matcher 初始化脚本 (OpenAI API 版本 / 中文提示)
#
# 用法:
#   ./setup.sh [--help] [--start-dev]
#
# 说明:
#   本脚本会检查并安装运行项目所需的依赖（Node.js、npm、Python、pip、uv），
#   自动安装根目录依赖、后端依赖、前端依赖，生成 .env 配置文件。
#
# 注意:
#   本版本不再安装 Ollama，使用 OpenAI API。
#

set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
IFS=$'\n\t'

# 检测系统类型
OS="$(uname -s)"
case "$OS" in
  Linux*)   OS_TYPE="Linux" ;;
  Darwin*)  OS_TYPE="macOS" ;;
  *)        OS_TYPE="$OS" ;;
esac

#–– 帮助信息 ––#
usage() {
  cat <<EOF
用法: \$0 [--help] [--start-dev]

选项:
  --help       显示此帮助信息并退出
  --start-dev  初始化完成后直接启动开发服务器

本脚本将会执行以下操作:
  • 检查运行环境: node, npm, python3, pip3, uv
  • 安装根目录依赖
  • 初始化 环境配置文件(.env)
  • 创建并配置后端虚拟环境，安装 Python 依赖
  • 安装前端依赖
EOF
}

START_DEV=false
if [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
elif [[ "${1:-}" == "--start-dev" ]]; then
  START_DEV=true
fi

#–– 日志输出函数 ––#
info()    { echo -e "ℹ  $*"; }
success() { echo -e "✅ $*"; }
error()   { echo -e "❌ $*" >&2; exit 1; }

info "检测到操作系统: $OS_TYPE"

#–– 1. 检查前置条件 ––#
check_cmd() {
  local cmd=$1
  if ! command -v "$cmd" &> /dev/null; then
    error "未安装命令: $cmd ，请安装后重试。"
  fi
}

check_node_version() {
  local min_major=18
  local ver
  ver=$(node --version | sed 's/^v\([0-9]*\).*/\1/')
  if (( ver < min_major )); then
    error "Node.js 版本过低，需要 v${min_major}+（当前版本: $(node --version)）"
  fi
}

info "检查运行环境依赖…"
check_cmd node
check_node_version
check_cmd npm
check_cmd python3

if ! command -v pip3 &> /dev/null; then
  if [[ "$OS_TYPE" == "Linux" && -x "$(command -v apt-get)" ]]; then
    info "未找到 pip3，使用 apt-get 安装…"
    sudo apt-get update && sudo apt-get install -y python3-pip || error "安装 python3-pip 失败"
  elif [[ "$OS_TYPE" == "Linux" && -x "$(command -v yum)" ]]; then
    info "未找到 pip3，使用 yum 安装…"
    sudo yum install -y python3-pip || error "安装 python3-pip 失败"
  else
    info "未找到 pip3，尝试 ensurepip 安装…"
    python3 -m ensurepip --upgrade || error "ensurepip 安装失败"
  fi
fi
check_cmd pip3
success "pip3 检测通过"

# 确认 uv
if ! command -v uv &> /dev/null; then
  info "未找到 uv，正在安装…"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
check_cmd uv
success "uv 检测通过，环境依赖满足。"

#–– 2. 初始化根目录 .env ––#
if [[ -f .env.example && ! -f .env ]]; then
  info "正在根据 .env.example 创建根目录 .env 文件"
  cp .env.example .env
  success "根目录 .env 文件已创建，请填写你的 OPENAI_API_KEY"
elif [[ -f .env ]]; then
  info "根目录 .env 已存在，跳过。"
else
  info "未找到 .env.example，跳过创建"
fi

#–– 3. 安装根目录依赖 ––#
info "安装根目录依赖 (npm ci)…"
npm ci
success "根依赖安装完成"

#–– 4. 安装后端依赖 ––#
info "配置后端 (apps/backend)…"
(
  cd apps/backend

  if [[ -f .env.sample && ! -f .env ]]; then
    info "正在根据 .env.sample 创建后端 .env 文件"
    cp .env.sample .env
    success "后端 .env 文件已创建，请填写你的 OPENAI_API_KEY"
  else
    info "后端 .env 已存在或 .env.sample 缺失，跳过。"
  fi

  info "同步 Python 依赖 (uv sync)…"
  uv sync
  success "后端依赖安装完成"
)

#–– 5. 安装前端依赖 ––#
info "配置前端 (apps/frontend)…"
(
  cd apps/frontend

  if [[ -f .env.sample && ! -f .env ]]; then
    info "正在根据 .env.sample 创建前端 .env 文件"
    cp .env.sample .env
    success "前端 .env 文件已创建"
  else
    info "前端 .env 已存在或 .env.sample 缺失，跳过。"
  fi

  info "安装前端依赖 (npm ci)…"
  npm ci
  success "前端依赖安装完成"
)

#–– 6. 完成 ––#
if [[ "$START_DEV" == true ]]; then
  info "启动开发服务器…"
  trap 'info "收到退出信号，正在关闭开发服务器..."; exit 0' SIGINT
  npm run dev
else
  success "🎉 环境初始化完成！
下一步:
  1. 编辑 .env 文件，填入你的 OPENAI_API_KEY
  2. 运行 npm run dev 启动开发模式
  3. 运行 npm run build 进行生产构建
"
fi
