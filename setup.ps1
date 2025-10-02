# setup.ps1 - PowerShell setup script for Resume Matcher

[CmdletBinding()]
param(
    [switch]$Help,
    [switch]$StartDev,
    [ValidateSet('auto', 'china', 'global')]
    [string]$NetworkProfile = 'auto'
)

$ErrorActionPreference = "Stop"

$script:DevServerPidFile = Join-Path $PSScriptRoot ".devserver.pid"
$script:InterfaceLocale = 'global'

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

function Remove-Utf8Bom {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        return
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $encoding = New-Object System.Text.UTF8Encoding($false)
            $content = $encoding.GetString($bytes, 3, $bytes.Length - 3)
            [System.IO.File]::WriteAllText($FilePath, $content, $encoding)
        }
    } catch {
        Write-Info "处理 $FilePath 的 BOM 时出现问题：$($_.Exception.Message)"
    }
}

function Ensure-BackendEnv {
    if (-not $script:ActiveMessages) {
        $script:ActiveMessages = $script:Messages['global']
    }

    $backendEnv = Join-Path $PSScriptRoot "apps/backend/.env"
    $backendSample = Join-Path $PSScriptRoot "apps/backend/.env.sample"

    if (-not (Test-Path $backendEnv)) {
        if (Test-Path $backendSample) {
            Write-Info ($script:ActiveMessages.CopyEnv -f 'apps/backend/.env.sample', 'apps/backend/.env')
            Copy-Item -Path $backendSample -Destination $backendEnv
        } else {
            New-Item -Path $backendEnv -ItemType File | Out-Null
        }
        Write-Success ($script:ActiveMessages.EnvCreated -f 'backend .env')
    }

    Remove-Utf8Bom -FilePath $backendEnv
    return $backendEnv
}

function Select-InterfaceLanguage {
    while ($true) {
        Write-Host ""
        Write-Host "Select interface language / 选择脚本显示语言" -ForegroundColor Yellow
        Write-Host "1) 简体中文"
        Write-Host "2) English"
        $choice = Read-Host "请输入编号 / Enter choice"

        switch ($choice) {
            '1' {
                $script:InterfaceLocale = 'china'
                $script:ActiveMessages = $script:Messages['china']
                Clear-Host
                return
            }
            '2' {
                $script:InterfaceLocale = 'global'
                $script:ActiveMessages = $script:Messages['global']
                Clear-Host
                return
            }
            default {
                Write-Host "无效选项，请重新输入 / Invalid option, try again" -ForegroundColor Yellow
            }
        }
    }
}

function Ensure-FrontendEnv {
    if (-not $script:ActiveMessages) {
        $script:ActiveMessages = $script:Messages['global']
    }

    $frontendEnv = Join-Path $PSScriptRoot "apps/frontend/.env"
    $frontendSample = Join-Path $PSScriptRoot "apps/frontend/.env.sample"

    if (-not (Test-Path $frontendEnv)) {
        if (Test-Path $frontendSample) {
            Write-Info ($script:ActiveMessages.CopyEnv -f 'apps/frontend/.env.sample', 'apps/frontend/.env')
            Copy-Item -Path $frontendSample -Destination $frontendEnv
        } else {
            New-Item -Path $frontendEnv -ItemType File | Out-Null
        }
        Write-Success ($script:ActiveMessages.EnvCreated -f 'frontend .env')
    }

    Remove-Utf8Bom -FilePath $frontendEnv
    return $frontendEnv
}

function Pause-ForMenu {
    if ($script:InterfaceLocale -eq 'china') {
        [void](Read-Host "按回车返回菜单")
    } else {
        [void](Read-Host "Press Enter to return to menu")
    }
}

function Confirm-Action {
    param(
        [string]$QuestionZh,
        [string]$QuestionEn
    )

    while ($true) {
        if ($script:InterfaceLocale -eq 'china') {
            $answer = Read-Host "$QuestionZh (Y/N)"
        } else {
            $answer = Read-Host "$QuestionEn (Y/N)"
        }

        if ([string]::IsNullOrWhiteSpace($answer)) {
            continue
        }

        switch ($answer.Trim().ToUpperInvariant()) {
            'Y' { return $true }
            'YES' { return $true }
            '是' { return $true }
            'S' { return $true }
            'N' { return $false }
            'NO' { return $false }
            '否' { return $false }
            default {
                if ($script:InterfaceLocale -eq 'china') {
                    Write-Host "请输入 Y 或 N" -ForegroundColor Yellow
                } else {
                    Write-Host "Please enter Y or N" -ForegroundColor Yellow
                }
            }
        }
    }
}

function Set-EnvEntry {
    param(
        [string]$FilePath,
        [string]$Key,
        [string]$Value
    )

    $normalizedValue = if ($null -eq $Value) { '' } else { [string]$Value }
    $escapedValue = $normalizedValue -replace '"', '""'
    $formattedLine = '{0}="{1}"' -f $Key, $escapedValue

    $existingLines = @()
    if (Test-Path $FilePath) {
        $existingLines = [System.IO.File]::ReadAllLines($FilePath)
        if ($existingLines.Length -gt 0) {
            $existingLines[0] = $existingLines[0] -replace "^[\uFEFF]", ''
        }
    }

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in $existingLines) {
        [void]$lines.Add($line)
    }

    $updated = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^\s*$Key\s*=") {
            $lines[$i] = $formattedLine
            $updated = $true
            break
        }
    }

    if (-not $updated) {
        [void]$lines.Add($formattedLine)
    }

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($FilePath, $lines.ToArray(), $encoding)
}

function Configure-OllamaProvider {
    Write-Info "配置本地 Ollama 模型提供商"
    $envPath = Ensure-BackendEnv

    $defaultLLModel = 'gemma3:4b'
    $defaultEmbeddingModel = 'nomic-embed-text:latest'

    $llModelInput = Read-Host "请输入对话模型名称 (默认 $defaultLLModel)"
    if ([string]::IsNullOrWhiteSpace($llModelInput)) { $llModelInput = $defaultLLModel }

    $embeddingModelInput = Read-Host "请输入向量模型名称 (默认 $defaultEmbeddingModel)"
    if ([string]::IsNullOrWhiteSpace($embeddingModelInput)) { $embeddingModelInput = $defaultEmbeddingModel }

    Set-EnvEntry -FilePath $envPath -Key 'LLM_PROVIDER' -Value 'ollama'
    Set-EnvEntry -FilePath $envPath -Key 'LLM_BASE_URL' -Value 'http://127.0.0.1:11434'
    Set-EnvEntry -FilePath $envPath -Key 'LLM_API_KEY' -Value ''
    Set-EnvEntry -FilePath $envPath -Key 'LL_MODEL' -Value $llModelInput

    Set-EnvEntry -FilePath $envPath -Key 'EMBEDDING_PROVIDER' -Value 'ollama'
    Set-EnvEntry -FilePath $envPath -Key 'EMBEDDING_BASE_URL' -Value 'http://127.0.0.1:11434'
    Set-EnvEntry -FilePath $envPath -Key 'EMBEDDING_API_KEY' -Value ''
    Set-EnvEntry -FilePath $envPath -Key 'EMBEDDING_MODEL' -Value $embeddingModelInput

    $frontendEnvPath = Ensure-FrontendEnv
    Set-EnvEntry -FilePath $frontendEnvPath -Key 'NEXT_PUBLIC_LLM_PROVIDER' -Value 'ollama'
    Set-EnvEntry -FilePath $frontendEnvPath -Key 'NEXT_PUBLIC_DEFAULT_MODEL' -Value $llModelInput
    Set-EnvEntry -FilePath $frontendEnvPath -Key 'NEXT_PUBLIC_MODEL_SELECTION' -Value 'disabled'

    Write-Success "已切换为本地 Ollama 配置"
}

function Configure-ApiProvider {
    Write-Info "配置远程 API 模型提供商"
    $envPath = Ensure-BackendEnv

    $defaultProvider = 'openai'
    $providerInput = Read-Host "请输入提供商标识 (默认 $defaultProvider)"
    if ([string]::IsNullOrWhiteSpace($providerInput)) { $providerInput = $defaultProvider }

    $defaultBaseUrl = 'https://api.openai.com/v1'
    $baseUrlInput = Read-Host "请输入 API Base URL (默认 $defaultBaseUrl)"
    if ([string]::IsNullOrWhiteSpace($baseUrlInput)) { $baseUrlInput = $defaultBaseUrl }

    $defaultLLModel = 'gpt-4.1'
    $llModelInput = Read-Host "请输入对话模型名称 (默认 $defaultLLModel)"
    if ([string]::IsNullOrWhiteSpace($llModelInput)) { $llModelInput = $defaultLLModel }

    $defaultEmbeddingModel = 'text-embedding-3-large'
    $embeddingModelInput = Read-Host "请输入向量模型名称 (默认 $defaultEmbeddingModel)"
    if ([string]::IsNullOrWhiteSpace($embeddingModelInput)) { $embeddingModelInput = $defaultEmbeddingModel }

    $apiKeyInput = Read-Host "请输入 API Key (回车保留现有值)"

    Set-EnvEntry -FilePath $envPath -Key 'LLM_PROVIDER' -Value $providerInput
    Set-EnvEntry -FilePath $envPath -Key 'LLM_BASE_URL' -Value $baseUrlInput
    Set-EnvEntry -FilePath $envPath -Key 'LL_MODEL' -Value $llModelInput

    Set-EnvEntry -FilePath $envPath -Key 'EMBEDDING_PROVIDER' -Value $providerInput
    Set-EnvEntry -FilePath $envPath -Key 'EMBEDDING_BASE_URL' -Value $baseUrlInput
    Set-EnvEntry -FilePath $envPath -Key 'EMBEDDING_MODEL' -Value $embeddingModelInput

    if (-not [string]::IsNullOrWhiteSpace($apiKeyInput)) {
        Set-EnvEntry -FilePath $envPath -Key 'LLM_API_KEY' -Value $apiKeyInput
        Set-EnvEntry -FilePath $envPath -Key 'EMBEDDING_API_KEY' -Value $apiKeyInput
    }

    $frontendEnvPath = Ensure-FrontendEnv
    Set-EnvEntry -FilePath $frontendEnvPath -Key 'NEXT_PUBLIC_LLM_PROVIDER' -Value $providerInput
    Set-EnvEntry -FilePath $frontendEnvPath -Key 'NEXT_PUBLIC_DEFAULT_MODEL' -Value $llModelInput
    Set-EnvEntry -FilePath $frontendEnvPath -Key 'NEXT_PUBLIC_MODEL_SELECTION' -Value 'enabled'

    Write-Success "已切换为远程 API 配置"
}

function Invoke-ProviderMenu {
    Clear-Host
    Write-Host ""
    if ($script:InterfaceLocale -eq 'china') {
        Write-Host "=== 模型提供商设置 ===" -ForegroundColor Yellow
        Write-Host "1) 使用本地 Ollama"
        Write-Host "2) 使用远程 API"
        Write-Host "0) 返回主菜单"
        $choice = Read-Host "请选择操作"
    } else {
        Write-Host "=== Model Provider Settings ===" -ForegroundColor Yellow
        Write-Host "1) Use local Ollama"
        Write-Host "2) Use remote API"
        Write-Host "0) Return to main menu"
        $choice = Read-Host "Select an option"
    }
    switch ($choice) {
        '1' { Configure-OllamaProvider }
        '2' { Configure-ApiProvider }
        default {
            if ($script:InterfaceLocale -eq 'china') {
                Write-Info "已返回主菜单"
            } else {
                Write-Info "Returning to main menu"
            }
        }
    }
    Pause-ForMenu
}

function Invoke-UpdateCheck {
    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
        Write-Info "未检测到 git，请先安装 Git。"
        return
    }

    Write-Info "同步远程仓库引用..."
    git fetch --all --prune
    Write-Success "远程引用已更新"

    $currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()
    Write-Info "当前分支：$currentBranch"

    Write-Host "--- git status -sb ---" -ForegroundColor Yellow
    git status -sb

    Write-Host "--- 与 origin/$currentBranch 的最近差异 ---" -ForegroundColor Yellow
    git log --oneline --decorate --max-count 5 "HEAD..origin/$currentBranch"
}

function Invoke-Uninstall {
    $targets = @(
        (Join-Path -Path $PSScriptRoot -ChildPath "node_modules"),
        (Join-Path -Path $PSScriptRoot -ChildPath "apps/frontend/node_modules"),
        (Join-Path -Path $PSScriptRoot -ChildPath "apps/backend/.venv")
    )

    $existingTargets = $targets | Where-Object { Test-Path $_ }
    if ($existingTargets.Count -eq 0) {
        Write-Info "未找到需要清理的依赖目录。"
        return
    }

    Write-Host "以下目录将被删除：" -ForegroundColor Yellow
    foreach ($target in $existingTargets) {
        Write-Host "  - $target"
    }

    $confirmation = Read-Host "请输入 YES 确认删除"
    if ($confirmation.ToUpperInvariant() -ne 'YES') {
        Write-Info "已取消卸载操作"
        return
    }

    foreach ($target in $existingTargets) {
        try {
            Remove-Item -Path $target -Recurse -Force
            Write-Success "已删除 $target"
        } catch {
            Write-Info "删除 $target 时出现问题：$($_.Exception.Message)"
        }
    }
}

function Get-HostShellPath {
    try {
        return (Get-Process -Id $PID).Path
    } catch {
        return (Join-Path $PSHOME 'pwsh.exe')
    }
}

function Invoke-StartDevServers {
    Ensure-BackendEnv | Out-Null

    if (Test-Path $script:DevServerPidFile) {
        $existingPid = Get-Content -Path $script:DevServerPidFile | Select-Object -First 1
        if ($existingPid -and (Get-Process -Id $existingPid -ErrorAction SilentlyContinue)) {
            Write-Info "开发服务器已在运行 (PID $existingPid)"
            return
        }
        Remove-Item -Path $script:DevServerPidFile -ErrorAction SilentlyContinue
    }

    $shellPath = Get-HostShellPath
    $startCommand = "Set-Location `"$PSScriptRoot`"; npm run dev"
    try {
        $process = Start-Process -FilePath $shellPath -ArgumentList '-NoExit', '-Command', $startCommand -PassThru
        Set-Content -Path $script:DevServerPidFile -Value $process.Id -Encoding UTF8
        Write-Success "已在新终端启动开发服务器 (PID $($process.Id))"
        Write-Info "关闭该终端或使用菜单的停止选项即可终止服务"
    } catch {
        Write-Info "启动开发服务器失败：$($_.Exception.Message)"
    }
}

function Invoke-StopDevServers {
    if (-not (Test-Path $script:DevServerPidFile)) {
        Write-Info "未记录正在运行的开发服务器"
        return
    }

    $pidContent = Get-Content -Path $script:DevServerPidFile | Select-Object -First 1
    $parsedPid = 0
    if (-not [int]::TryParse($pidContent, [ref]$parsedPid)) {
        Remove-Item -Path $script:DevServerPidFile -ErrorAction SilentlyContinue
        Write-Info "PID 信息已失效，已清理记录"
        return
    }

    $pidValue = $parsedPid
    try {
        Stop-Process -Id $pidValue -ErrorAction Stop
        Write-Success "已停止开发服务器 (PID $pidValue)"
    } catch {
        Write-Info "停止进程时出现问题：$($_.Exception.Message)"
    }

    Remove-Item -Path $script:DevServerPidFile -ErrorAction SilentlyContinue
}

function Show-MainMenu {
    while ($true) {
        Clear-Host
        Write-Host ""
        if ($script:InterfaceLocale -eq 'china') {
            Write-Host "=== Resume Matcher 安装助手 ===" -ForegroundColor Yellow
            Write-Host "1) 安装/修复依赖"
            Write-Host "2) 检查仓库更新"
            Write-Host "3) 更改模型提供商"
            Write-Host "4) 启动开发服务器"
            Write-Host "5) 停止开发服务器"
            Write-Host "6) 卸载本地依赖"
            Write-Host "0) 退出"
            $choice = Read-Host "请选择操作"
        } else {
            Write-Host "=== Resume Matcher Setup Assistant ===" -ForegroundColor Yellow
            Write-Host "1) Install / Repair dependencies"
            Write-Host "2) Check repository updates"
            Write-Host "3) Change model provider"
            Write-Host "4) Start dev servers"
            Write-Host "5) Stop dev servers"
            Write-Host "6) Uninstall local dependencies"
            Write-Host "0) Exit"
            $choice = Read-Host "Select an option"
        }

        switch ($choice) {
            '1' {
                if ($script:InterfaceLocale -eq 'china') {
                    $profileInput = Read-Host "选择网络模式 (auto/china/global，默认 auto)"
                } else {
                    $profileInput = Read-Host "Select network profile (auto/china/global, default auto)"
                }
                if ([string]::IsNullOrWhiteSpace($profileInput)) { $profileInput = 'auto' }
                Invoke-Install -RequestedProfile $profileInput
                Pause-ForMenu
            }
            '2' {
                $confirm = Confirm-Action "确认执行仓库更新检查？" "Run repository update check?"
                if ($confirm) {
                    Clear-Host
                    Invoke-UpdateCheck
                } else {
                    if ($script:InterfaceLocale -eq 'china') {
                        Write-Info "已取消仓库更新检查"
                    } else {
                        Write-Info "Update check cancelled"
                    }
                }
                Pause-ForMenu
            }
            '3' { Invoke-ProviderMenu }
            '4' { Invoke-StartDevServers; Pause-ForMenu }
            '5' { Invoke-StopDevServers; Pause-ForMenu }
            '6' { Invoke-Uninstall; Pause-ForMenu }
            '0' { break }
            default {
                if ($script:InterfaceLocale -eq 'china') {
                    Write-Info "无效选项，请重新输入"
                } else {
                    Write-Info "Invalid option, please try again"
                }
                Pause-ForMenu
            }
        }
    }
}

function Invoke-Install {
    param(
        [string]$RequestedProfile = 'auto',
        [switch]$StartDev
    )

    $initialLocale = if ($RequestedProfile -eq 'china') { 'china' } else { 'global' }
    $script:ActiveMessages = $script:Messages[$initialLocale]

    $resolvedProfile = Resolve-NetworkProfile -RequestedProfile $RequestedProfile
    $script:ActiveMessages = $script:Messages[$resolvedProfile]

    Write-Info $script:ActiveMessages.Start
    Apply-PackageMirrors -Profile $resolvedProfile

    if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
        Write-CustomError ($script:ActiveMessages.NodeMissing)
    }
    $nodeVersion = node --version
    $nodeMajor = [int]($nodeVersion -replace '^v(\d+).*', '$1')
    if ($nodeMajor -lt 18) {
        Write-CustomError ($script:ActiveMessages.NodeOld -f $nodeVersion)
    }
    Write-Success ($script:ActiveMessages.NodeOk -f $nodeVersion)

    if (-not (Get-Command "npm" -ErrorAction SilentlyContinue)) {
        Write-CustomError ($script:ActiveMessages.NpmMissing)
    }
    Write-Success ($script:ActiveMessages.NpmOk -f $script:NpmRegistry)

    $PythonCmd = if (Get-Command "python3" -ErrorAction SilentlyContinue) { "python3" } elseif (Get-Command "python" -ErrorAction SilentlyContinue) { "python" } else { $null }
    if (-not $PythonCmd) {
        Write-CustomError ($script:ActiveMessages.PythonMissing)
    }
    Write-Success ($script:ActiveMessages.PythonOk -f $PythonCmd)

    $PipCmd = if (Get-Command "pip3" -ErrorAction SilentlyContinue) { "pip3" } elseif (Get-Command "pip" -ErrorAction SilentlyContinue) { "pip" } else { $null }
    if (-not $PipCmd) {
        Write-CustomError ($script:ActiveMessages.PipMissing)
    }
    Write-Success ($script:ActiveMessages.PipOk -f $script:PipIndex)

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

    $rootEnvPath = Join-Path -Path $PSScriptRoot -ChildPath ".env"
    $rootEnvExample = Join-Path -Path $PSScriptRoot -ChildPath ".env.example"
    if ((Test-Path $rootEnvExample) -and (-not (Test-Path $rootEnvPath))) {
        Write-Info ($script:ActiveMessages.CopyEnv -f '.env.example', '.env')
        Copy-Item $rootEnvExample $rootEnvPath
        Write-Success ($script:ActiveMessages.EnvCreated -f 'root .env')
    } elseif (Test-Path $rootEnvPath) {
        Write-Info ($script:ActiveMessages.EnvExists -f 'root .env')
    }
    Remove-Utf8Bom -FilePath $rootEnvPath

    Write-Info ($script:ActiveMessages.InstallWorkspace)
    npm install

    if (Test-Path "apps/backend") {
        Push-Location "apps/backend"

        $backendEnvPath = Join-Path -Path (Get-Location).Path -ChildPath ".env"
        if ((Test-Path ".env.sample") -and (-not (Test-Path $backendEnvPath))) {
            Write-Info ($script:ActiveMessages.CopyEnv -f 'apps/backend/.env.sample', '.env')
            Copy-Item ".env.sample" $backendEnvPath
            Write-Success ($script:ActiveMessages.EnvCreated -f 'backend .env')
        }
        Remove-Utf8Bom -FilePath $backendEnvPath

        if (-not (Test-Path ".venv")) {
            Write-Info ($script:ActiveMessages.CreateVenv)
            uv venv
        }

        Write-Info ($script:ActiveMessages.SyncBackend -f $script:PipIndex)
        uv sync
        Pop-Location
    }

    if (Test-Path "apps/frontend") {
        Ensure-FrontendEnv | Out-Null
        Push-Location "apps/frontend"
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
}

if ($Help) {
    $helpLocale = if ($NetworkProfile -eq 'china') { 'china' } else { 'global' }
    Write-Host $script:HelpTexts[$helpLocale]
    Write-Host "无参数运行脚本将进入交互式菜单。"
    exit 0
}

$nonHelpParameters = $PSBoundParameters.Keys | Where-Object { $_ -ne 'Help' }
if ($nonHelpParameters.Count -gt 0) {
    Invoke-Install -RequestedProfile $NetworkProfile -StartDev:$StartDev
} else {
    Select-InterfaceLanguage
    Show-MainMenu
}
