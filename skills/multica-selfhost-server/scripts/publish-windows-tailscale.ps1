<# Publish the local same-origin gateway privately with Tailscale Serve. #>

[CmdletBinding()]
param(
    [string] $WslDistro = "Ubuntu-26.04",
    [string] $LinuxRepo = "",
    [string] $Profile = "home",
    [ValidateRange(1, 65535)] [int] $GatewayPort = 8787,
    [ValidateRange(5, 120)] [int] $TimeoutSeconds = 30,
    [ValidateRange(2, 15)] [int] $ProbeTimeoutSeconds = 5,
    [switch] $InstallServerAutostart,
    [string] $TailscalePath = ""
)

$ErrorActionPreference = "Stop"
if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid Multica profile: $Profile" }
$GatewayUrl = "http://127.0.0.1:$GatewayPort"
$ReadinessArguments = @{
    Profile = $Profile; GatewayPort = $GatewayPort; ProbeTimeoutSeconds = $ProbeTimeoutSeconds
}
if ($TailscalePath) { $ReadinessArguments.TailscalePath = $TailscalePath }
$ReadinessRaw = & (Join-Path $PSScriptRoot "check-windows-tailscale-readiness.ps1") @ReadinessArguments
$Readiness = $ReadinessRaw | ConvertFrom-Json
if ($Readiness.status -ne "ready") {
    Write-Output $ReadinessRaw
    return
}
$PublishedUrl = [string]$Readiness.published_url

try { $GatewayResponse = Invoke-WebRequest "$GatewayUrl/api/config" -TimeoutSec 5 }
catch { throw "The local Multica gateway is unavailable at $GatewayUrl." }
if ($GatewayResponse.StatusCode -ne 200) { throw "The local Multica gateway is unhealthy." }

$Starter = Join-Path $PSScriptRoot "start-windows-wsl-server.ps1"
& $Starter -WslDistro $WslDistro -LinuxRepo $LinuxRepo -Profile $Profile `
    -PublishedUrl $PublishedUrl -GatewayPort $GatewayPort
if ($LASTEXITCODE -ne 0) { throw "Could not apply the published URL to the server." }

if ($InstallServerAutostart) {
    $Installer = Join-Path $PSScriptRoot "install-windows-wsl-server-autostart.ps1"
    & $Installer -WslDistro $WslDistro -LinuxRepo $LinuxRepo -Profile $Profile `
        -PublishedUrl $PublishedUrl -GatewayPort $GatewayPort
    if ($LASTEXITCODE -ne 0) { throw "Could not install server autostart." }
} else {
    Write-Output "Server autostart was not changed. Pass -InstallServerAutostart only after explicit approval."
}

$Reachable = $false
for ($Attempt = 0; $Attempt -lt $TimeoutSeconds; $Attempt++) {
    try {
        if ((Invoke-WebRequest "$PublishedUrl/api/config" -TimeoutSec 3).StatusCode -eq 200) {
            $Reachable = $true
            break
        }
    } catch {}
    Start-Sleep -Seconds 1
}
if (-not $Reachable) { throw "Tailscale Serve was configured, but $PublishedUrl did not become reachable." }
& (Join-Path $PSScriptRoot "profile-cache.ps1") set -Profile $Profile `
    -Entry "ONBOARDING_PHASE=server-ready" *> $null
Write-Output "Private Multica Server URL: $PublishedUrl"
Get-Content -Raw -LiteralPath (Join-Path $env:USERPROFILE ".multica\selfhost-server\$Profile\connection.json")
