<# Prepare only the native-Windows server phase; cluster onboarding continues with the runtime-client Skill. #>

[CmdletBinding()]
param(
    [string] $MulticaRepo = $env:MULTICA_REPO,
    [string] $Profile = "local",
    [string] $PublishedUrl = "",
    [ValidateRange(1, 65535)] [int] $GatewayPort = 8787,
    [switch] $Clone,
    [switch] $Up
)

$ErrorActionPreference = "Stop"
$GitUrl = "https://github.com/multica-ai/multica.git"
$ComposeFile = "docker-compose.selfhost.yml"
function Have([string] $Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

if ([string]::IsNullOrWhiteSpace($MulticaRepo)) { throw "Specify -MulticaRepo." }
if (Test-Path -LiteralPath (Join-Path $MulticaRepo $ComposeFile)) {
    Write-Output "Multica server checkout found: $MulticaRepo"
} elseif ($Clone) {
    if (-not (Have "git")) { throw "git is required to clone the server repository." }
    if (Test-Path -LiteralPath $MulticaRepo) { throw "Clone target already exists: $MulticaRepo" }
    git clone --depth 1 $GitUrl $MulticaRepo
    if ($LASTEXITCODE -ne 0) { throw "Multica server clone failed." }
} else {
    throw "Server checkout is missing; pass -Clone or provide an existing checkout."
}

if (-not (Have "docker")) {
    if (-not (Have "winget")) { throw "Docker Desktop is missing and winget is unavailable." }
    $Answer = Read-Host "Install Docker Desktop with winget? (Y/n)"
    if ($Answer -ne "" -and $Answer -notmatch '^(y|yes)$') { throw "Docker Desktop installation declined." }
    winget install -e --id Docker.DockerDesktop --source winget `
        --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw "Docker Desktop installation failed." }
    throw "Docker Desktop was installed. Start it once, then rerun this script."
}
docker info *> $null
if ($LASTEXITCODE -ne 0) { throw "Docker is installed but its engine is not running." }

if ($Up) {
    & (Join-Path $PSScriptRoot "server.ps1") up -MulticaRepo $MulticaRepo `
        -Profile $Profile -PublishedUrl $PublishedUrl -GatewayPort $GatewayPort
    if ($LASTEXITCODE -ne 0) { throw "Server startup failed." }
} else {
    Write-Output "Server prerequisites are ready. Run server.ps1 up to start the stack."
}
