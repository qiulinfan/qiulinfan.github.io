<# Publish the local same-origin gateway privately with Tailscale Serve. #>

[CmdletBinding()]
param(
    [string] $WslDistro = "Ubuntu-26.04",
    [string] $LinuxRepo = "",
    [string] $Profile = "local",
    [ValidateRange(1, 65535)] [int] $GatewayPort = 8787,
    [ValidateRange(10, 300)] [int] $TimeoutSeconds = 90,
    [switch] $InstallServerAutostart
)

$ErrorActionPreference = "Stop"
if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid Multica profile: $Profile" }
$GatewayUrl = "http://127.0.0.1:$GatewayPort"
$TailscaleCandidates = @(
    (Join-Path $env:ProgramFiles "Tailscale\tailscale.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Tailscale\tailscale.exe")
)
$TailscaleCommand = Get-Command tailscale.exe -ErrorAction SilentlyContinue
if ($TailscaleCommand) { $TailscaleCandidates = @($TailscaleCommand.Source) + $TailscaleCandidates }
$Tailscale = $TailscaleCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $Tailscale) {
    throw "Tailscale is not installed. Install Tailscale.Tailscale from Winget in an elevated terminal."
}
try { $GatewayResponse = Invoke-WebRequest "$GatewayUrl/api/config" -TimeoutSec 5 }
catch { throw "The local Multica gateway is unavailable at $GatewayUrl." }
if ($GatewayResponse.StatusCode -ne 200) { throw "The local Multica gateway is unhealthy." }

function Get-TailscaleStatus {
    $Raw = ((& $Tailscale status --json 2>$null) -join "`n")
    if ($LASTEXITCODE -ne 0 -or -not $Raw) { return $null }
    try { return $Raw | ConvertFrom-Json } catch { return $null }
}

$Status = Get-TailscaleStatus
if (-not $Status -or $Status.BackendState -ne "Running") {
    Write-Output "Tailscale needs an interactive sign-in; follow the browser prompt opened by 'tailscale up'."
    & $Tailscale up
    if ($LASTEXITCODE -ne 0) { throw "Tailscale sign-in did not complete." }
    $Status = Get-TailscaleStatus
}
if (-not $Status -or $Status.BackendState -ne "Running") { throw "Tailscale is not connected." }
$DnsName = [string]$Status.Self.DNSName
$DnsName = $DnsName.Trim().TrimEnd('.')
if ($DnsName -notmatch '^[A-Za-z0-9.-]+\.ts\.net$') { throw "Could not resolve the Tailscale DNS name." }
$PublishedUrl = "https://$DnsName"

& $Tailscale serve --bg --yes $GatewayUrl
if ($LASTEXITCODE -ne 0) {
    throw "Tailscale Serve could not be enabled. Complete any HTTPS consent prompt and retry."
}

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
Write-Output "Private Multica Server URL: $PublishedUrl"
Get-Content -Raw -LiteralPath (Join-Path $env:USERPROFILE ".multica\selfhost-server\$Profile\connection.json")
