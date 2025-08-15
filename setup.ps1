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
  -Help       显示此帮助消息并退出
  -StartDev   安装完成后，启动开发服务器

这个仅限Windows的PowerShell脚本将：
  - 验证所需工具：node、npm、python3、pip3、uv
  - 通过npm安装根依赖项
  - 引导根文件和后端/前端.env文件
  - 设置后端Python venv并通过uv安装依赖项
  - 通过npm安装前端依赖项

核心依赖项：
  - Node.js v18+
  - npm
  - Python 3
  - pip
  - uv (will attempt auto-install via 国内镜像)
"@
    exit 0
}

function Write-Info { param([string]$Message) Write-Host "ℹ  $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "✔ $Message" -ForegroundColor Green }
function Write-CustomError { param([string]$Message) Write-Host "✘ $Message" -ForegroundColor Red; exit 1 }

Write-Info "启动Resume Matcher（OpenAI API 模式）设置..."

# 为本进程使用国内镜像源（不修改全局配置）
$env:NPM_CONFIG_REGISTRY = "https://registry.npmmirror.com"
$env:PIP_INDEX_URL = "https://pypi.tuna.tsinghua.edu.cn/simple"
# uv 在解析 PyPI 时也会读取 pip 的 index-url；同时设置 UV_INDEX_URL（若支持）
$env:UV_INDEX_URL = $env:PIP_INDEX_URL

Write-Info "本次安装使用国内镜像：npm=$env:NPM_CONFIG_REGISTRY, PyPI=$env:PIP_INDEX_URL"

# 检查 Node.js
if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
    Write-CustomError "Node.js未安装，请安装Node.js v18+后重试"
}
$Version = node --version
$Major = [int]($Version -replace "^v(\d+).*", '\$1')
if ($Major -lt 18) {
    Write-CustomError "Node.js版本过低，需要v18+（当前 $Version）"
}
Write-Success "Node.js $Version 检测通过"

# 检查 npm
if (-not (Get-Command "npm" -ErrorAction SilentlyContinue)) {
    Write-CustomError "npm未安装，请安装npm后重试"
}
Write-Success "npm检测通过（使用国内镜像 $env:NPM_CONFIG_REGISTRY）"

# 检查 Python
$PythonCmd = if (Get-Command "python3" -ErrorAction SilentlyContinue) { "python3" } elseif (Get-Command "python" -ErrorAction SilentlyContinue) { "python" } else { $null }
if (-not $PythonCmd) { Write-CustomError "未检测到Python 3，请安装 Python 3" }
Write-Success "Python检测通过: $PythonCmd"

# 检查 pip
$PipCmd = if (Get-Command "pip3" -ErrorAction SilentlyContinue) { "pip3" } elseif (Get-Command "pip" -ErrorAction SilentlyContinue) { "pip" } else { $null }
if (-not $PipCmd) { Write-CustomError "未检测到pip，请安装 pip" }
Write-Success "pip检测通过: $PipCmd（使用国内镜像 $env:PIP_INDEX_URL）"

# 检查 uv（若不存在则用国内镜像安装）
if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-Info "uv未检测到，尝试使用国内镜像安装..."

    # 候选安装脚本镜像（按顺序尝试）
    $installerUrls = @(
        "https://mirror.ghproxy.com/https://astral.sh/uv/install.ps1",
        "https://ghproxy.com/https://astral.sh/uv/install.ps1",
        "https://astral.sh/uv/install.ps1" # 最后回退官方
    )

    $scriptContent = $null
    foreach ($u in $installerUrls) {
        try {
            Write-Info "获取安装脚本：$u"
            $resp = Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 30
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300 -and $resp.Content) {
                $scriptContent = $resp.Content
                break
            }
        } catch {
            Write-Info "获取失败：$($_.Exception.Message)，尝试下一个镜像..."
        }
    }

    if (-not $scriptContent) {
        Write-CustomError "无法获取 uv 安装脚本（镜像与官方均失败），请手动安装：https://docs.astral.sh/uv/"
    }

    # 将脚本内的 GitHub 资源域名重写为镜像加速
    $scriptContent = $scriptContent `
        -replace 'https://github.com', 'https://mirror.ghproxy.com/https://github.com' `
        -replace 'https://objects.githubusercontent.com', 'https://mirror.ghproxy.com/https://objects.githubusercontent.com'

    # 执行安装脚本
    Invoke-Expression $scriptContent

    # 更新 PATH（uv 默认安装到 %USERPROFILE%\.local\bin）
    $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
}

if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-CustomError "uv 安装失败，请参考文档手动安装：https://docs.astral.sh/uv/"
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

# 安装根依赖（使用国内 npm 源）
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
        Write-Info "创建 Python 虚拟环境（uv venv）"
        uv venv
    }
    Write-Info "同步 Python 依赖（uv sync，使用 PyPI 镜像 $env:PIP_INDEX_URL）"
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
    Write-Info "安装前端依赖（npm install）"
    npm install
    Pop-Location
}

Write-Success "✅ 安装完成！"
Write-Host "下一步操作：" -ForegroundColor Yellow
Write-Host "  1. 打开 .env 文件并填入你的OPENAI_API_KEY和URL" -ForegroundColor Yellow
Write-Host "  2. 运行 'npm run dev' 启动开发模式" -ForegroundColor Yellow

if ($StartDev) {
    npm run dev
}
