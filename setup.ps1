# setup.ps1 - PowerShell setup script for Resume Matcher

[CmdletBinding()]
param(
    [switch]$Help,
    [switch]$StartDev,
    [ValidateSet('auto', 'china', 'global')]
    [string]$NetworkProfile = 'auto'
)

$ErrorActionPreference = "Stop"

$script:Messages = @{
    'global' = @{
        Start = "Starting Resume Matcher setup..."
        ForcedProfile = "Using forced network profile: {0}"
        AutoDetect = "Auto-detecting network connectivity..."
        Probe = "Probe {0} ({1}) => {2}"
        AutoResult = "Auto-detect result: {0} profile (override with -NetworkProfile global|china)"
        Registries = "Active registries -> npm: {0}, PyPI: {1}"
        NodeMissing = "Node.js was not found. Please install Node.js v18+ first."
        NodeOld = "Node.js version {0} is too old. v18+ is required."
        NpmMissing = "npm was not found. Please install npm and retry."
        NodeOk = "Node.js {0} detected"
        NpmOk = "npm detected (registry {0})"
        PythonMissing = "Python 3 was not found. Please install Python 3."
        PythonOk = "Python detected via {0}"
        PipMissing = "pip was not found. Please install pip."
        PipOk = "pip detected (index {0})"
        UvInstalling = "uv not found. Attempting automatic installation..."
        Downloading = "Downloading installer: {0}"
        DownloadFailed = "Failed: {0}. Trying next mirror..."
        UvDownloadFail = "Unable to download uv installer. See https://docs.astral.sh/uv/ for manual steps."
        UvInstallFail = "uv installation failed. Please install it manually: https://docs.astral.sh/uv/"
        UvOk = "uv detected"
        CopyEnv = "Copying {0} -> {1}"
        EnvCreated = "{0} created. Please fill in the required secrets."
        EnvExists = "{0} already exists"
        InstallWorkspace = "Installing workspace npm dependencies"
        CreateVenv = "Creating Python virtual environment (uv venv)"
        SyncBackend = "Syncing backend Python dependencies via uv sync (index {0})"
        InstallFrontend = "Installing frontend dependencies (npm install)"
        Done = "Dependency installation completed"
        Next = "Next steps:"
        Next1 = "  1. Populate API credentials inside the generated .env files"
        Next2 = "  2. Run 'npm run dev' to start the development servers"
        Reachable = 'reachable'
        Unreachable = 'unreachable'
    }
    'china' = @{
        Start = "开始运行 Resume Matcher 安装脚本..."
        ForcedProfile = "已选择网络模式：{0}"
        AutoDetect = "正在自动探测网络可达性..."
        Probe = "探测 {0} ({1}) => {2}"
        AutoResult = "自动判定为：{0} 模式（可添加 -NetworkProfile global 或 china 手动覆盖）"
        Registries = "当前使用的源 -> npm: {0}，PyPI: {1}"
        NodeMissing = "未检测到 Node.js，请先安装 Node.js v18+"
        NodeOld = "Node.js 版本 {0} 过低，需要 v18+"
        NpmMissing = "未检测到 npm，请安装后重试"
        NodeOk = "Node.js {0} 检测通过"
        NpmOk = "npm 检测通过（源 {0}）"
        PythonMissing = "未检测到 Python 3，请先安装"
        PythonOk = "Python 检测通过，执行命令：{0}"
        PipMissing = "未检测到 pip，请先安装"
        PipOk = "pip 检测通过（索引 {0}）"
        UvInstalling = "未检测到 uv，尝试自动安装..."
        Downloading = "下载安装脚本：{0}"
        DownloadFailed = "下载失败：{0}，尝试下一镜像..."
        UvDownloadFail = "无法获取 uv 安装脚本，请参考 https://docs.astral.sh/uv/ 手动安装"
        UvInstallFail = "uv 安装失败，请参考 https://docs.astral.sh/uv/ 手动安装"
        UvOk = "uv 检测通过"
        CopyEnv = "复制 {0} -> {1}"
        EnvCreated = "已创建 {0}，请补充相关密钥"
        EnvExists = "{0} 已存在"
        InstallWorkspace = "安装仓库级 npm 依赖"
        CreateVenv = "创建 Python 虚拟环境（uv venv）"
        SyncBackend = "同步后端依赖（uv sync，PyPI 源 {0}）"
        InstallFrontend = "安装前端依赖（npm install）"
        Done = "依赖安装完成"
        Next = "后续步骤："
        Next1 = "  1. 在各 .env 中填入所需的 API Key"
        Next2 = "  2. 运行 'npm run dev' 启动开发服务器"
        Reachable = '可达'
        Unreachable = '不可达'
    }
}

$script:HelpTexts = @{
    'global' = @"
Usage: .\setup.ps1 [-Help] [-StartDev] [-NetworkProfile <auto|china|global>]

Options:
  -Help             Show this help and exit
  -StartDev         Run 'npm run dev' after dependencies are installed
  -NetworkProfile   Pick network mode: auto (default auto-detect), china (domestic mirrors), global (official registries)

Steps performed:
  1. Check Node.js / npm / Python / pip / uv
  2. Configure registries according to the selected network profile
  3. Copy .env example files (root, backend, frontend)
  4. Create the backend virtual environment and install dependencies via uv
  5. Install frontend dependencies

Prerequisites:
  - Node.js v18+
  - npm
  - Python 3
  - pip
  - uv (auto-install attempted when missing)
"@
    'china' = @"
用法： .\setup.ps1 [-Help] [-StartDev] [-NetworkProfile <auto|china|global>]

参数说明：
  -Help             显示本帮助并退出
  -StartDev         安装完成后自动执行 'npm run dev'
  -NetworkProfile   网络模式：auto（自动探测）、china（国内镜像）、global（官方源）

脚本流程：
  1. 检查 Node.js / npm / Python / pip / uv
  2. 根据网络模式切换 npm 与 PyPI 源
  3. 复制根目录、后端、前端的 .env 示例
  4. 创建后端虚拟环境并通过 uv 安装依赖
  5. 安装前端依赖

执行前请确保已安装：
  - Node.js v18+
  - npm
  - Python 3
  - pip
  - uv（如缺失会尝试自动安装）
"@
}

$script:ActiveMessages = $null

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

function Write-Info {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-CustomError {
    param([string]$Message)
    Write-Host "[x] $Message" -ForegroundColor Red
    exit 1
}

function Test-Endpoint {
    param(
        [string]$Url,
        [int]$TimeoutSec = 5
    )

    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -Method Head -TimeoutSec $TimeoutSec | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Resolve-NetworkProfile {
    param([string]$RequestedProfile)

    switch ($RequestedProfile) {
        'china' {
            Write-Info ($script:ActiveMessages.ForcedProfile -f 'china')
            return 'china'
        }
        'global' {
            Write-Info ($script:ActiveMessages.ForcedProfile -f 'global')
            return 'global'
        }
        default {
            Write-Info $script:ActiveMessages.AutoDetect
            $chinaEndpoints = @(
                @{ Name = 'TUNA PyPI'; Url = 'https://pypi.tuna.tsinghua.edu.cn/simple' },
                @{ Name = 'npmmirror'; Url = 'https://registry.npmmirror.com' }
            )

            $allReachable = $true
            foreach ($endpoint in $chinaEndpoints) {
                $reachable = Test-Endpoint -Url $endpoint.Url -TimeoutSec 5
                $statusLabel = if ($reachable) { $script:ActiveMessages.Reachable } else { $script:ActiveMessages.Unreachable }
                Write-Info ($script:ActiveMessages.Probe -f $endpoint.Name, $endpoint.Url, $statusLabel)
                if (-not $reachable) { $allReachable = $false }
            }

            if ($allReachable) {
                Write-Info ($script:ActiveMessages.AutoResult -f 'china')
                return 'china'
            }

            Write-Info ($script:ActiveMessages.AutoResult -f 'global')
            return 'global'
        }
    }
}

function Apply-PackageMirrors {
    param([string]$Profile)

    switch ($Profile) {
        'china' {
            $script:NpmRegistry = 'https://registry.npmmirror.com'
            $script:PipIndex = 'https://pypi.tuna.tsinghua.edu.cn/simple'
            $script:UvIndex = $script:PipIndex
        }
        default {
            $script:NpmRegistry = 'https://registry.npmjs.org'
            $script:PipIndex = 'https://pypi.org/simple'
            $script:UvIndex = $script:PipIndex
        }
    }

    $env:NPM_CONFIG_REGISTRY = $script:NpmRegistry
    $env:PIP_INDEX_URL = $script:PipIndex
    $env:UV_INDEX_URL = $script:UvIndex

    Write-Info ($script:ActiveMessages.Registries -f $script:NpmRegistry, $script:PipIndex)
}

if ($Help) {
    $helpLocale = if ($NetworkProfile -eq 'china') { 'china' } else { 'global' }
    Write-Host $script:HelpTexts[$helpLocale]
    exit 0
}

$script:ActiveMessages = if ($NetworkProfile -eq 'china') { $script:Messages['china'] } else { $script:Messages['global'] }
$resolvedProfile = Resolve-NetworkProfile -RequestedProfile $NetworkProfile
$script:ActiveMessages = $script:Messages[$resolvedProfile]

Write-Info $script:ActiveMessages.Start
Apply-PackageMirrors -Profile $resolvedProfile

# Node.js
if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
    Write-CustomError ($script:ActiveMessages.NodeMissing)
}
$nodeVersion = node --version
$nodeMajor = [int]($nodeVersion -replace '^v(\d+).*', '$1')
if ($nodeMajor -lt 18) {
    Write-CustomError ($script:ActiveMessages.NodeOld -f $nodeVersion)
}
Write-Success ($script:ActiveMessages.NodeOk -f $nodeVersion)

# npm
if (-not (Get-Command "npm" -ErrorAction SilentlyContinue)) {
    Write-CustomError ($script:ActiveMessages.NpmMissing)
}
Write-Success ($script:ActiveMessages.NpmOk -f $script:NpmRegistry)

# Python
$PythonCmd = if (Get-Command "python3" -ErrorAction SilentlyContinue) { "python3" } elseif (Get-Command "python" -ErrorAction SilentlyContinue) { "python" } else { $null }
if (-not $PythonCmd) {
    Write-CustomError ($script:ActiveMessages.PythonMissing)
}
Write-Success ($script:ActiveMessages.PythonOk -f $PythonCmd)

# pip
$PipCmd = if (Get-Command "pip3" -ErrorAction SilentlyContinue) { "pip3" } elseif (Get-Command "pip" -ErrorAction SilentlyContinue) { "pip" } else { $null }
if (-not $PipCmd) {
    Write-CustomError ($script:ActiveMessages.PipMissing)
}
Write-Success ($script:ActiveMessages.PipOk -f $script:PipIndex)

# uv (install when missing)
if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-Info ($script:ActiveMessages.UvInstalling)

    $installerUrls = if ($resolvedProfile -eq 'china') {
        @(
            'https://mirror.ghproxy.com/https://astral.sh/uv/install.ps1',
            'https://ghproxy.com/https://astral.sh/uv/install.ps1',
            'https://astral.sh/uv/install.ps1'
        )
    } else {
        @('https://astral.sh/uv/install.ps1')
    }

    $scriptContent = $null
    foreach ($url in $installerUrls) {
        try {
            Write-Info ($script:ActiveMessages.Downloading -f $url)
            $resp = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300 -and $resp.Content) {
                $scriptContent = $resp.Content
                break
            }
        } catch {
            Write-Info ($script:ActiveMessages.DownloadFailed -f $_.Exception.Message)
        }
    }

    if (-not $scriptContent) {
        Write-CustomError ($script:ActiveMessages.UvDownloadFail)
    }

    if ($resolvedProfile -eq 'china') {
        $scriptContent = $scriptContent -replace 'https://github.com', 'https://mirror.ghproxy.com/https://github.com' -replace 'https://objects.githubusercontent.com', 'https://mirror.ghproxy.com/https://objects.githubusercontent.com'
    }

    Invoke-Expression $scriptContent
    $env:PATH = "${env:USERPROFILE}\.local\bin;${env:PATH}"
}

if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-CustomError ($script:ActiveMessages.UvInstallFail)
}
Write-Success ($script:ActiveMessages.UvOk)

# Root .env
if ((Test-Path ".env.example") -and (-not (Test-Path ".env"))) {
    Write-Info ($script:ActiveMessages.CopyEnv -f '.env.example', '.env')
    Copy-Item ".env.example" ".env"
    Write-Success ($script:ActiveMessages.EnvCreated -f 'root .env')
} elseif (Test-Path ".env") {
    Write-Info ($script:ActiveMessages.EnvExists -f 'root .env')
}

# Root dependencies
Write-Info ($script:ActiveMessages.InstallWorkspace)
npm install

# Backend setup
if (Test-Path "apps/backend") {
    Push-Location "apps/backend"

    if ((Test-Path ".env.sample") -and (-not (Test-Path ".env"))) {
        Write-Info ($script:ActiveMessages.CopyEnv -f 'apps/backend/.env.sample', '.env')
        Copy-Item ".env.sample" ".env"
        Write-Success ($script:ActiveMessages.EnvCreated -f 'backend .env')
    }

    if (-not (Test-Path ".venv")) {
        Write-Info ($script:ActiveMessages.CreateVenv)
        uv venv
    }

    Write-Info ($script:ActiveMessages.SyncBackend -f $script:PipIndex)
    uv sync
    Pop-Location
}

# Frontend setup
if (Test-Path "apps/frontend") {
    Push-Location "apps/frontend"
    if ((Test-Path ".env.sample") -and (-not (Test-Path ".env"))) {
        Write-Info ($script:ActiveMessages.CopyEnv -f 'apps/frontend/.env.sample', '.env')
        Copy-Item ".env.sample" ".env"
        Write-Success ($script:ActiveMessages.EnvCreated -f 'frontend .env')
    }
    Write-Info ($script:ActiveMessages.InstallFrontend)
    npm install
    Pop-Location
}

Write-Success ($script:ActiveMessages.Done)
Write-Host ($script:ActiveMessages.Next) -ForegroundColor Yellow
Write-Host ($script:ActiveMessages.Next1) -ForegroundColor Yellow
Write-Host ($script:ActiveMessages.Next2) -ForegroundColor Yellow

if ($StartDev) {
    npm run dev
}
