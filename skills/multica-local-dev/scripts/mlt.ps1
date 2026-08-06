<#
================================================================================
 mlt.ps1  --  Multica self-hosted 环境控制器（随 skill 分发）

 与旧版不同：不假设任何仓库布局。只需要一份**开源 multica 仓库**的 clone
 （含 docker-compose.selfhost.yml），路径通过 -MulticaRepo 或 $env:MULTICA_REPO 指定。

 启停「self-hosted server(Docker) + daemon(可配置 profile)」，并提供
 debug 日志：daemon 执行轨迹 / server 侧事件 / agent 跑 issue 的产物目录。

 Profile、server URL、workspace 与开发登录参数都可通过命令行覆盖。脚本只负责
 环境操作，不规定 repository、issue、PR 或 agent 工作流策略。

 用法（先设仓库路径，二选一）：
   $env:MULTICA_REPO = "C:\path\to\multica"        # 之后可省略 -MulticaRepo
   .\mlt.ps1 up -MulticaRepo C:\path\to\multica

   up      启动 server + daemon（首次引导登录）
   auto    全自动：server + 自动登录(dev码) + daemon + workspace
   down    停 daemon + 停 server 容器（保留数据）
   down -Wipe   停并删除数据卷（清空 DB，需 YES 确认）
   status | logs <daemon|server|web|db> | code | tasks [-Tail] | watch | debug
================================================================================
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Command = "help",
    [Parameter(Position = 1)] [string] $Arg1 = "",
    [string] $MulticaRepo = $env:MULTICA_REPO,
    [string] $Profile = $(if ($env:MULTICA_PROFILE) { $env:MULTICA_PROFILE } else { "localtest" }),
    [string] $ServerUrl = $(if ($env:MULTICA_SERVER_URL) { $env:MULTICA_SERVER_URL } else { "http://127.0.0.1:8080" }),
    [string] $AppUrl = $(if ($env:MULTICA_APP_URL) { $env:MULTICA_APP_URL } else { "http://127.0.0.1:3000" }),
    [string] $WorkspaceName = "",
    [string] $WorkspaceSlug = "",
    [string] $AutoEmail = "dev@localtest.local",
    [string] $DevCode = "888888",
    [switch] $Follow,
    [switch] $Tail,
    [switch] $Wipe,
    [int] $Lines = 200
)

$ErrorActionPreference = "Stop"

# ----------------------------- 配置 ---------------------------
$ComposeFile   = "docker-compose.selfhost.yml"
if ([string]::IsNullOrWhiteSpace($WorkspaceName)) { $WorkspaceName = $Profile }
if ([string]::IsNullOrWhiteSpace($WorkspaceSlug)) {
    $WorkspaceSlug = ($WorkspaceName.ToLowerInvariant() -replace '[^a-z0-9-]+', '-') -replace '(^-|-$)', ''
}
if ([string]::IsNullOrWhiteSpace($WorkspaceSlug)) { $WorkspaceSlug = "workspace" }
$WorkspacesRoot = Join-Path $env:USERPROFILE ("multica_workspaces_" + $Profile)
$DaemonLog      = Join-Path $env:USERPROFILE (".multica\profiles\$Profile\daemon.log")
# -------------------------------------------------------------

function Say([string]$m, [string]$color = "Cyan") { Write-Host $m -ForegroundColor $color }
function Warn([string]$m) { Write-Host $m -ForegroundColor Yellow }
function Die([string]$m)  { Write-Host $m -ForegroundColor Red; exit 1 }

function Resolve-MulticaRepo {
    if ([string]::IsNullOrWhiteSpace($MulticaRepo)) {
        # 兜底：若当前目录就是 multica 仓库根
        if (Test-Path (Join-Path $PWD $ComposeFile)) { return (Resolve-Path $PWD).Path }
        Die "未指定 multica 仓库路径。用 -MulticaRepo <path> 或先 `$env:MULTICA_REPO=<path>`（该目录须含 $ComposeFile）。"
    }
    if (-not (Test-Path $MulticaRepo)) { Die "路径不存在：$MulticaRepo" }
    return (Resolve-Path $MulticaRepo).Path
}
$MulticaRepo = Resolve-MulticaRepo

function Resolve-DockerExe {
    $c = Get-Command docker -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $fallback = Join-Path $env:ProgramFiles "Docker\Docker\resources\bin\docker.exe"
    if (Test-Path $fallback) { return $fallback }
    return $null
}
$DockerExe = Resolve-DockerExe
if ($DockerExe) {
    $dkDir = Split-Path $DockerExe
    if ($env:PATH -notlike "*$dkDir*") { $env:PATH = "$dkDir;$env:PATH" }
}

function Assert-Ready {
    if ([string]::IsNullOrWhiteSpace($Profile)) { Die "Profile 不能为空。传 -Profile <name>。" }
    if (-not (Test-Path (Join-Path $MulticaRepo $ComposeFile))) {
        Die "找不到 $ComposeFile @ $MulticaRepo。请指向开源 multica 仓库根（含 $ComposeFile）。"
    }
    if (-not (Get-Command multica -ErrorAction SilentlyContinue)) {
        Die "PATH 上没有 multica CLI。先跑 bootstrap.ps1 装依赖。"
    }
    if (-not $DockerExe) { Die "找不到 docker。先装 Docker Desktop 并启动（bootstrap.ps1）。" }
}

function Compose { param([Parameter(ValueFromRemainingArguments)] $rest)
    Push-Location $MulticaRepo
    try { & $DockerExe compose -f $ComposeFile @rest }
    finally { Pop-Location }
}

function Ensure-Env {
    $envPath = Join-Path $MulticaRepo ".env"
    if (-not (Test-Path $envPath)) {
        Say "未发现 .env，从 .env.example 生成并写入随机 JWT_SECRET..."
        Copy-Item (Join-Path $MulticaRepo ".env.example") $envPath
        $bytes = New-Object byte[] 32
        [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        $jwt = -join ($bytes | ForEach-Object { $_.ToString("x2") })
        (Get-Content $envPath) -replace '^JWT_SECRET=.*', "JWT_SECRET=$jwt" | Set-Content $envPath
        (Get-Content $envPath) -replace '^APP_ENV=.*', "APP_ENV=development" | Set-Content $envPath
        Add-Content $envPath "`nMULTICA_DEV_VERIFICATION_CODE=$DevCode"
        Warn "已写入 APP_ENV=development + 固定验证码 $DevCode（本地测试用）。"
    }
}

function Wait-Health {
    Say "等待 backend 健康 (${ServerUrl}/health)..."
    for ($i = 0; $i -lt 40; $i++) {
        try {
            $r = Invoke-WebRequest -Uri "$ServerUrl/health" -TimeoutSec 2 -UseBasicParsing
            if ($r.StatusCode -eq 200) { Say "OK backend 就绪" Green; return $true }
        } catch { Start-Sleep -Milliseconds 1500 }
    }
    Warn "backend 迟迟未就绪，看日志：.\mlt.ps1 logs server -MulticaRepo $MulticaRepo"
    return $false
}

function Daemon-Authed {
    try {
        $out = & multica auth status --profile $Profile 2>&1 | Out-String
        return ($out -match "(?i)valid|logged in|authenticated|$ServerUrl")
    } catch { return $false }
}

function Get-PatViaApi {
    try {
        Invoke-RestMethod -Uri "$ServerUrl/auth/send-code" -Method Post -ContentType "application/json" `
            -Body (@{ email = $AutoEmail } | ConvertTo-Json) -TimeoutSec 10 | Out-Null
    } catch { Warn "send-code 提示（可忽略）：$_" }
    $vr = Invoke-RestMethod -Uri "$ServerUrl/auth/verify-code" -Method Post -ContentType "application/json" `
            -Body (@{ email = $AutoEmail; code = $DevCode } | ConvertTo-Json) -TimeoutSec 10
    $jwt = $vr.token
    if (-not $jwt) { throw "verify-code 未返回 token" }
    $pr = Invoke-RestMethod -Uri "$ServerUrl/api/tokens" -Method Post -ContentType "application/json" `
            -Headers @{ Authorization = "Bearer $jwt" } `
            -Body (@{ name = "$Profile-auto" } | ConvertTo-Json) -TimeoutSec 10
    $pat = $pr.token
    if (-not $pat) { throw "创建 PAT 未返回 token" }
    return @{ jwt = $jwt; pat = $pat }
}

function Ensure-Workspace([string]$jwt) {
    try {
        $list = Invoke-RestMethod -Uri "$ServerUrl/api/workspaces" -Method Get `
            -Headers @{ Authorization = "Bearer $jwt" } -TimeoutSec 10
        if ($list -and @($list).Count -gt 0) { Say "已有 workspace：$(@($list)[0].name)"; return }
    } catch { Warn "查 workspace 失败（继续尝试创建）：$_" }
    Say "无 workspace，自动创建 '$WorkspaceName'..."
    try {
        Invoke-RestMethod -Uri "$ServerUrl/api/workspaces" -Method Post -ContentType "application/json" `
            -Headers @{ Authorization = "Bearer $jwt" } `
            -Body (@{ name = $WorkspaceName; slug = $WorkspaceSlug } | ConvertTo-Json) -TimeoutSec 10 | Out-Null
        Say "OK 已创建 workspace '$WorkspaceName' ($WorkspaceSlug)" Green
    } catch { Warn "创建 workspace 失败：$_（可在 Web 手动建）" }
}

function Cmd-Up {
    Assert-Ready; Ensure-Env
    Say "=== [1/3] 启动本地 Multica server (Docker) ==="
    Compose up -d
    if (-not (Wait-Health)) { return }
    Say "=== [2/3] 配置并登录 daemon profile '$Profile' ==="
    if (Daemon-Authed) { Say "profile 已登录，直接起 daemon。"; & multica daemon start --profile $Profile }
    else {
        Warn "profile 未登录 —— 走 setup self-host（会开浏览器/要验证码 $DevCode）。"
        & multica setup self-host --profile $Profile --server-url $ServerUrl --app-url $AppUrl
    }
    Say "=== [3/3] 状态 ==="; Cmd-Status
    Say "`n前端： $AppUrl   后端： $ServerUrl" Green
}

function Cmd-Auto {
    Assert-Ready; Ensure-Env
    Say "=== 全自动：server + 自动登录 + daemon + workspace ==="
    Compose up -d
    if (-not (Wait-Health)) { return }
    $jwt = $null
    if (Daemon-Authed) { Say "profile 已登录，跳过自动登录。" }
    else {
        Say "自动登录（账号 $AutoEmail + dev 码 $DevCode）..."
        try {
            $cred = Get-PatViaApi; $jwt = $cred.jwt
            & multica config set server_url $ServerUrl --profile $Profile | Out-Null
            & multica config set app_url $AppUrl --profile $Profile | Out-Null
            & multica login --token $cred.pat --profile $Profile
            Say "OK 已用自动 PAT 登录。" Green
        } catch { Warn "自动登录失败：$_ —— 回退 multica login --profile $Profile（码 $DevCode）"; return }
    }
    & multica daemon start --profile $Profile
    if (-not $jwt) { try { $jwt = (Get-PatViaApi).jwt } catch {} }
    if ($jwt) { Ensure-Workspace $jwt }
    Cmd-Status
    Say "`n全自动完成。前端 $AppUrl 建 agent+issue。调试： .\mlt.ps1 watch -MulticaRepo $MulticaRepo" Green
}

function Cmd-Down {
    Assert-Ready
    Say "停 daemon profile '$Profile' ..."
    try { & multica daemon stop --profile $Profile } catch { Warn "daemon 可能本就没在跑。" }
    if ($Wipe) {
        Warn "!! -Wipe 会删除 self-hosted server 的 DB 数据卷（不可恢复）。"
        $ans = Read-Host "确认清空？输入大写 YES 继续"
        if ($ans -ceq "YES") { Compose down -v; Say "已停止并清空数据卷。" Green }
        else { Warn "已取消清库，仅停容器（保留数据）。"; Compose down }
    } else { Compose down; Say "已停 server 容器（数据卷保留）。" Green }
}

function Cmd-Status {
    Assert-Ready
    Say "--- server 容器 ---"; Compose ps
    Say "`n--- daemon [$Profile] ---"
    try { & multica daemon status --profile $Profile } catch { Warn "daemon 未运行。" }
    Say "`n--- backend health ---"
    try { (Invoke-WebRequest "$ServerUrl/health" -TimeoutSec 2 -UseBasicParsing).Content } catch { Warn "backend 不可达。" }
}

function Cmd-Logs {
    Assert-Ready
    switch ($Arg1) {
        "daemon" { Say "跟 daemon.log：$DaemonLog"; & multica daemon logs --profile $Profile -f -n $Lines }
        "server" { Say "跟 backend 容器日志"; Compose logs -f --tail $Lines backend }
        "web"    { Compose logs -f --tail $Lines frontend }
        "db"     { Compose logs -f --tail $Lines postgres }
        default  { Warn "用法：.\mlt.ps1 logs <daemon|server|web|db> -MulticaRepo <path>" }
    }
}

function Cmd-Code {
    Assert-Ready
    Say "从 backend 日志抓最近验证码..."
    Push-Location $MulticaRepo
    try { $log = & $DockerExe compose -f $ComposeFile logs --tail 500 backend 2>&1 | Out-String } finally { Pop-Location }
    $codes = [regex]::Matches($log, "(?i)(code|verification)[^0-9]{0,20}(\d{4,8})")
    if ($codes.Count -gt 0) { Say ("最新验证码： " + $codes[$codes.Count - 1].Groups[2].Value) Green }
    else { Warn "日志没抓到。若设了 MULTICA_DEV_VERIFICATION_CODE，直接用它（默认 888888）。" }
}

function Get-TaskDirs {
    if (-not (Test-Path $WorkspacesRoot)) { return @() }
    Get-ChildItem $WorkspacesRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue
    } | Where-Object { $_.Name -ne ".multica" } | Sort-Object LastWriteTime -Descending
}

function Cmd-Tasks {
    Assert-Ready
    $dirs = Get-TaskDirs
    if (-not $dirs -or $dirs.Count -eq 0) { Warn "还没有任务产物。产物根： $WorkspacesRoot"; return }
    Say "agent 跑过的任务目录（时间倒序，根：$WorkspacesRoot）："
    $i = 0
    foreach ($d in $dirs | Select-Object -First 15) { $i++; Say ("  [{0}] {1}  <ws:{2}>  {3}" -f $i, $d.Name, $d.Parent.Name, $d.LastWriteTime) White }
    if ($Tail) {
        $latest = $dirs[0]; Say "`n跟最新任务： $($latest.FullName)" Green
        $targets = @()
        foreach ($sub in @("logs", "output")) {
            $p = Join-Path $latest.FullName $sub
            if (Test-Path $p) { $targets += (Get-ChildItem $p -File -Recurse -ErrorAction SilentlyContinue).FullName }
        }
        if ($targets.Count -eq 0) { Warn "该任务暂无 logs/output 文件。"; Get-ChildItem $latest.FullName -Recurse | Select-Object FullName, Length, LastWriteTime }
        else { Get-Content -Path $targets -Wait -Tail 50 }
    }
}

function Cmd-Watch {
    Assert-Ready
    Say "=== 实时组合调试视图（Ctrl+C 退出）===" Green
    $dirs = Get-TaskDirs
    if ($dirs.Count -gt 0) { Say "最新任务： $($dirs[0].FullName)" White }
    & multica daemon logs --profile $Profile -f -n $Lines
}

function Cmd-Debug {
    Assert-Ready
    Say "================ Multica 本地排障快照 ================" Green
    Cmd-Status
    Say "`n--- 近期任务目录（top 10）---"
    $dirs = Get-TaskDirs
    if ($dirs.Count -eq 0) { Warn "无任务产物 @ $WorkspacesRoot" }
    else { $dirs | Select-Object -First 10 | ForEach-Object { Say ("  {0}  <ws:{1}>  {2}" -f $_.Name, $_.Parent.Name, $_.LastWriteTime) White } }
    Say "`n--- daemon.log 尾部 60 行 ---"
    if (Test-Path $DaemonLog) { Get-Content $DaemonLog -Tail 60 } else { Warn "无 daemon.log @ $DaemonLog" }
    Say "`n--- backend 日志尾部 60 行 ---"
    Push-Location $MulticaRepo
    try { & $DockerExe compose -f $ComposeFile logs --tail 60 backend } catch { Warn "取 backend 日志失败。" } finally { Pop-Location }
    Say "`n=====================================================" Green
}

function Cmd-Help { Get-Content $PSCommandPath | Select-Object -First 40 | ForEach-Object { Write-Host $_ } }

switch ($Command.ToLower()) {
    "up"     { Cmd-Up }
    "auto"   { Cmd-Auto }
    "down"   { Cmd-Down }
    "status" { Cmd-Status }
    "logs"   { Cmd-Logs }
    "code"   { Cmd-Code }
    "tasks"  { Cmd-Tasks }
    "watch"  { Cmd-Watch }
    "debug"  { Cmd-Debug }
    default  { Cmd-Help }
}
