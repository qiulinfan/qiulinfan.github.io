<#
================================================================================
 bootstrap.ps1  --  开箱即用依赖安装器（自包含 / 可移植版，随 skill 分发）

 假设目标机器**除开源 multica 仓库外一无所有**。本脚本负责把缺的都补上：
   1. 开源 multica 仓库  —— 缺失时 git clone（github.com/multica-ai/multica）
   2. multica CLI         —— 官方开源安装脚本
   3. Docker Desktop      —— 检测；缺失时用 winget 安装（需确认）

 Agent provider CLI 不由本脚本安装。按实际需要另行安装并登录 Codex、Claude、
 OpenCode、OpenClaw 或 Multica 支持的其它 runtime。

 用法：
   .\bootstrap.ps1 -MulticaRepo C:\path\to\multica            仅装依赖
   .\bootstrap.ps1 -MulticaRepo C:\path\to\multica -Clone     缺仓库则 git clone 到该路径
   .\bootstrap.ps1 -MulticaRepo C:\path\to\multica -Clone -Up 装完并启动 self-hosted 环境(auto)
================================================================================
#>

[CmdletBinding()]
param(
    [string] $MulticaRepo = $env:MULTICA_REPO,
    [string] $Profile = $(if ($env:MULTICA_PROFILE) { $env:MULTICA_PROFILE } else { "localtest" }),
    [string] $ServerUrl = $(if ($env:MULTICA_SERVER_URL) { $env:MULTICA_SERVER_URL } else { "http://127.0.0.1:8080" }),
    [string] $AppUrl = $(if ($env:MULTICA_APP_URL) { $env:MULTICA_APP_URL } else { "http://127.0.0.1:3000" }),
    [string] $WorkspaceName = "",
    [string] $WorkspaceSlug = "",
    [string] $AutoEmail = "dev@localtest.local",
    [string] $DevCode = "888888",
    [switch] $Clone,
    [switch] $Up
)

$ErrorActionPreference = "Stop"
$MulticaGitUrl = "https://github.com/multica-ai/multica.git"
$ComposeFile   = "docker-compose.selfhost.yml"

function Say([string]$m, [string]$c = "Cyan") { Write-Host $m -ForegroundColor $c }
function Warn([string]$m) { Write-Host $m -ForegroundColor Yellow }
function Have([string]$exe) { return [bool](Get-Command $exe -ErrorAction SilentlyContinue) }
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

Say "================ Multica 依赖安装（可移植版）================" Green

# --- 0. 开源 multica 仓库 ---------------------------------------------------
if ([string]::IsNullOrWhiteSpace($MulticaRepo)) {
    Warn "未指定 -MulticaRepo。装完 CLI/Docker 后，请把开源 multica 仓库路径设给 mlt.ps1。"
} elseif (Test-Path (Join-Path $MulticaRepo $ComposeFile)) {
    Say "OK 已找到开源 multica 仓库：$MulticaRepo"
} elseif ($Clone) {
    if (-not (Have "git")) { Warn "无 git，无法自动 clone。请手动装 git 或拷贝 multica 仓库到 $MulticaRepo。" }
    else {
        Say "clone 开源 multica → $MulticaRepo ..."
        git clone --depth 1 $MulticaGitUrl $MulticaRepo
        if (Test-Path (Join-Path $MulticaRepo $ComposeFile)) { Say "OK 仓库就位" Green } else { Warn "clone 后仍未见 $ComposeFile，请检查。" }
    }
} else {
    Warn "路径 $MulticaRepo 下没有 $ComposeFile。加 -Clone 自动 git clone，或手动放置仓库。"
}

# --- 1. multica CLI ---------------------------------------------------------
if (Have "multica") { Say "OK multica CLI 已安装：$((Get-Command multica).Source)" }
else {
    Say "装 multica CLI（官方开源安装脚本）..."
    $ProgressPreference = "SilentlyContinue"
    Invoke-RestMethod https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.ps1 | Invoke-Expression
    Refresh-Path
    if (Have "multica") { Say "OK multica 安装完成" Green } else { Warn "multica 装完仍未在 PATH，重开终端确认。" }
}

# --- 2. Docker --------------------------------------------------------------
if (Have "docker") {
    Say "OK docker 已安装：$((Get-Command docker).Source)"
    try { docker info *> $null; Say "OK Docker 引擎在运行" Green }
    catch { Warn "Docker 已装但引擎没起，请打开 Docker Desktop 后再跑 mlt.ps1 up。" }
} else {
    Warn "未检测到 Docker。"
    if (Have "winget") {
        $ans = Read-Host "用 winget 安装 Docker Desktop？(Y/n)"
        if ($ans -eq "" -or $ans -match "^(y|yes)$") {
            winget install -e --id Docker.DockerDesktop --source winget --accept-source-agreements --accept-package-agreements
            Warn "Docker Desktop 装好后需手动启动一次（可能要重启），再跑 mlt.ps1 up。"
        } else { Warn "跳过。手动装：https://www.docker.com/products/docker-desktop/" }
    } else { Warn "无 winget。手动装 Docker Desktop：https://www.docker.com/products/docker-desktop/" }
}

# --- 3. Agent provider CLI -------------------------------------------------
$ProviderCommands = @("codex", "claude", "opencode", "openclaw")
$DetectedProviders = @($ProviderCommands | Where-Object { Have $_ })
if ($DetectedProviders.Count -gt 0) {
    Say ("已检测到 provider CLI：" + ($DetectedProviders -join ", ")) Green
} else {
    Warn "未检测到常见 provider CLI。server/daemon 仍可安装；运行 Agent 前请另行安装并登录所选 runtime。"
}

Say "`n================ 依赖检查完成 ================" Green
Say "multica  : $((Get-Command multica  -ErrorAction SilentlyContinue).Source)"
Say "docker   : $((Get-Command docker   -ErrorAction SilentlyContinue).Source)"
Say "providers: $($DetectedProviders -join ', ')"

if ($Up -and -not [string]::IsNullOrWhiteSpace($MulticaRepo)) {
    Say "`n-Up 指定：启动 self-hosted 环境(auto)..." Green
    & (Join-Path $PSScriptRoot "mlt.ps1") auto `
        -MulticaRepo $MulticaRepo -Profile $Profile `
        -ServerUrl $ServerUrl -AppUrl $AppUrl `
        -WorkspaceName $WorkspaceName -WorkspaceSlug $WorkspaceSlug `
        -AutoEmail $AutoEmail -DevCode $DevCode
} else {
    Say "`n下一步：  .\mlt.ps1 auto -MulticaRepo $MulticaRepo -Profile $Profile" Green
}
