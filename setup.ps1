# setup.ps1 - PowerShell setup script for Resume Matcher (OpenAI API version)

[CmdletBinding()]
param(
    [switch]$Help,
    [switch]$StartDev
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Write-Host @"
Usage: .\setup.ps1 [-Help] [-StartDev]

Options:
  -Help       Show this help message and exit
  -StartDev   After setup completes, start the dev server

This Windows-only PowerShell script will:
  - Verify required tools: node, npm, python3, pip3, uv
  - Install root dependencies via npm
  - Bootstrap both root and backend/frontend .env files
  - Setup backend Python venv and install dependencies via uv
  - Install frontend dependencies via npm

CORE DEPENDENCIES:
  - Node.js v18+
  - npm
  - Python 3
  - pip
  - uv (will attempt auto-install)
"@
    exit 0
}

function Write-Info { param([string]$Message) Write-Host "ℹ  $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "✔ $Message" -ForegroundColor Green }
function Write-CustomError { param([string]$Message) Write-Host "✘ $Message" -ForegroundColor Red; exit 1 }

Write-Info "Starting Resume Matcher (OpenAI API mode) setup..."

# 检查 Node.js
if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
    Write-CustomError "Node.js 未安装，请安装 Node.js v18+ 后重试"
}
$Version = node --version
$Major = [int]($Version -replace "^v(\d+).*", '\$1')
if ($Major -lt 18) {
    Write-CustomError "Node.js 版本过低，需要 v18+（当前 $Version）"
}
Write-Success "Node.js $Version 检测通过"

# 检查 npm
if (-not (Get-Command "npm" -ErrorAction SilentlyContinue)) {
    Write-CustomError "npm 未安装，请安装 npm 后重试"
}
Write-Success "npm 检测通过"

# 检查 Python
$PythonCmd = if (Get-Command "python3" -ErrorAction SilentlyContinue) { "python3" } elseif (Get-Command "python" -ErrorAction SilentlyContinue) { "python" } else { $null }
if (-not $PythonCmd) { Write-CustomError "未检测到 Python 3，请安装 Python 3" }
Write-Success "Python 检测通过: $PythonCmd"

# 检查 pip
$PipCmd = if (Get-Command "pip3" -ErrorAction SilentlyContinue) { "pip3" } elseif (Get-Command "pip" -ErrorAction SilentlyContinue) { "pip" } else { $null }
if (-not $PipCmd) { Write-CustomError "未检测到 pip，请安装 pip" }
Write-Success "pip 检测通过: $PipCmd"

# 检查 uv
if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-Info "uv 未检测到，尝试自动安装..."
    Invoke-Expression "powershell -ExecutionPolicy ByPass -c `"irm https://astral.sh/uv/install.ps1 | iex`""
    $env:PATH = "$env:USERPROFILE\.local\bin;" + $env:PATH
}
if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-CustomError "uv 安装失败，请手动安装：https://docs.astral.sh/uv/"
}
Write-Success "uv 检测通过"

# 初始化根目录 .env
if ((Test-Path ".env.example") -and (-not (Test-Path ".env"))) {
    Write-Info "从 .env.example 创建根目录配置文件 .env"
    Copy-Item ".env.example" ".env"
    Write-Success "根目录 .env 创建完成（请编辑填入 OPENAI_API_KEY）"
} elseif (Test-Path ".env") {
    Write-Info "根目录 .env 已存在"
}

# 安装根依赖
Write-Info "安装根依赖（npm install）"
npm install

# 后端环境
if (Test-Path "apps/backend") {
    Push-Location "apps/backend"
    if ((Test-Path ".env.sample") -and (-not (Test-Path ".env"))) {
        Write-Info "从 .env.sample 创建后端 .env"
        Copy-Item ".env.sample" ".env"
        Write-Success "后端 .env 创建完成（请编辑填入 OPENAI_API_KEY）"
    }

    if (-not (Test-Path ".venv")) {
        Write-Info "创建 Python 虚拟环境"
        uv venv
    }
    uv sync
    Pop-Location
}

# 前端环境
if (Test-Path "apps/frontend") {
    Push-Location "apps/frontend"
    if ((Test-Path ".env.sample") -and (-not (Test-Path ".env"))) {
        Write-Info "从 .env.sample 创建前端 .env"
        Copy-Item ".env.sample" ".env"
        Write-Success "前端 .env 创建完成"
    }
    npm install
    Pop-Location
}

Write-Success "✅ 安装完成！"
Write-Host "下一步操作：" -ForegroundColor Yellow
Write-Host "  1. 打开 .env 文件并填入你的 OPENAI_API_KEY" -ForegroundColor Yellow
Write-Host "  2. 运行 'npm run dev' 启动开发模式" -ForegroundColor Yellow

if ($StartDev) {
    npm run dev
}
