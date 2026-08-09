<# Prepare only the native-Windows server phase; cluster onboarding continues with the runtime-client Skill. #>

[CmdletBinding()]
param(
    [string] $MulticaRepo = $env:MULTICA_REPO,
    [string] $Profile = "home",
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
& (Join-Path $PSScriptRoot "profile-cache.ps1") set -Profile $Profile -Entry @(
    "TOPOLOGY=windows-native", "SERVER_REPO=$MulticaRepo", "GATEWAY_PORT=$GatewayPort",
    "PUBLISHED_URL=$PublishedUrl"
) *> $null
$CachedProfile = (& (Join-Path $PSScriptRoot "profile-cache.ps1") show -Profile $Profile) | ConvertFrom-Json
$Phase = [string]$CachedProfile.values.ONBOARDING_PHASE
if ($Phase -notin @("tailscale-ready", "server-ready", "owner-registration-required", "cluster-finalizing", "complete")) {
    throw "Tailscale readiness must be completed before clone, Docker installation, or server startup."
}
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

$EnvironmentPath = Join-Path $MulticaRepo ".env"
if (-not (Test-Path -LiteralPath $EnvironmentPath)) {
    $ExamplePath = Join-Path $MulticaRepo ".env.example"
    if (-not (Test-Path -LiteralPath $ExamplePath)) { throw "Multica .env.example is missing." }
    Copy-Item -LiteralPath $ExamplePath -Destination $EnvironmentPath
    $Bytes = New-Object byte[] 32
    $Generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $Generator.GetBytes($Bytes) } finally { $Generator.Dispose() }
    $Jwt = -join ($Bytes | ForEach-Object { $_.ToString("x2") })
    $Lines = [Collections.Generic.List[string]]::new()
    foreach ($Line in [IO.File]::ReadAllLines($EnvironmentPath)) { $Lines.Add($Line) }
    $Found = $false
    for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
        if ($Lines[$Index] -match '^JWT_SECRET=') {
            $Lines[$Index] = "JWT_SECRET=$Jwt"
            $Found = $true
            break
        }
    }
    if (-not $Found) { $Lines.Add("JWT_SECRET=$Jwt") }
    [IO.File]::WriteAllLines($EnvironmentPath, $Lines, [Text.UTF8Encoding]::new($false))
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
