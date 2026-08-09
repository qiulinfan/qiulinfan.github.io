<# One-time Windows onboarding against an existing Multica server. #>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ServerUrl,
    [string] $AppUrl = "",
    [Parameter(Mandatory)] [string] $Workspace,
    [string] $IdentityEmail = "",
    [ValidateSet("same-tailnet", "shared-machine")] [string] $TailscaleAccessMode = "same-tailnet",
    [string] $Profile = "remote",
    [string] $CallbackHost = "127.0.0.1",
    [string] $DeviceName = $env:COMPUTERNAME,
    [string] $RuntimeName = "",
    [ValidateRange(1, 50)] [int] $MaxConcurrentTasks = 1,
    [string] $AgentTimeout = "0s",
    [switch] $SkipCliInstall
)

$ErrorActionPreference = "Stop"
$InstallerUrl = "https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.ps1"
$MulticaExe = Join-Path $env:USERPROFILE ".multica\bin\multica.exe"

function Assert-HttpUrl([string] $Name, [string] $Value) {
    $Parsed = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref] $Parsed) -or
        $Parsed.Scheme -notin @("http", "https") -or
        -not [string]::IsNullOrEmpty($Parsed.UserInfo)) {
        throw "$Name must be an absolute http(s) URL without embedded credentials."
    }
}

if ([string]::IsNullOrWhiteSpace($AppUrl)) { $AppUrl = $ServerUrl }
Assert-HttpUrl "ServerUrl" $ServerUrl
Assert-HttpUrl "AppUrl" $AppUrl
if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid Multica profile: $Profile" }
if ([string]::IsNullOrWhiteSpace($Workspace)) { throw "Workspace is required." }
if ($Workspace -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid workspace reference." }
if ([string]::IsNullOrWhiteSpace($RuntimeName)) { $RuntimeName = "$DeviceName runtime" }

$CacheScript = Join-Path $PSScriptRoot "profile-cache.ps1"
$CacheEntries = @(
    "SERVER_URL=$ServerUrl", "APP_URL=$AppUrl", "WORKSPACE=$Workspace",
    "INVITATION_STATUS=unknown", "PLATFORM=windows", "DEVICE_NAME=$DeviceName", "RUNTIME_NAME=$RuntimeName",
    "TAILSCALE_ACCESS_MODE=$TailscaleAccessMode", "TAILSCALE_ACCESS_STATUS=unknown",
    "MAX_CONCURRENT_TASKS=$MaxConcurrentTasks", "AGENT_TIMEOUT=$AgentTimeout"
)
if ($IdentityEmail) { $CacheEntries += "IDENTITY_EMAIL=$IdentityEmail" }
& $CacheScript set -Profile $Profile -Entry $CacheEntries *> $null

$AccessCheck = Join-Path $PSScriptRoot "check-windows-tailscale-access.ps1"
& $AccessCheck -ServerUrl $ServerUrl -Profile $Profile -AccessMode $TailscaleAccessMode
if ($LASTEXITCODE -ne 0) { throw "Tailscale access to the Multica server is not ready." }

if (-not (Test-Path -LiteralPath $MulticaExe)) {
    $Existing = Get-Command multica.exe -ErrorAction SilentlyContinue
    if ($Existing) { $MulticaExe = $Existing.Source }
}
if (-not (Test-Path -LiteralPath $MulticaExe)) {
    if ($SkipCliInstall) { throw "Multica CLI is missing and -SkipCliInstall was specified." }
    Write-Output "Installing the Multica CLI only; no server components will be installed..."
    $Installer = Invoke-RestMethod -Uri $InstallerUrl
    $PreviousMode = $env:MULTICA_MODE
    try {
        Remove-Item Env:MULTICA_MODE -ErrorAction SilentlyContinue
        Invoke-Expression $Installer
    } finally {
        if ($null -ne $PreviousMode) { $env:MULTICA_MODE = $PreviousMode }
        else { Remove-Item Env:MULTICA_MODE -ErrorAction SilentlyContinue }
    }
    $MulticaExe = Join-Path $env:USERPROFILE ".multica\bin\multica.exe"
}
if (-not (Test-Path -LiteralPath $MulticaExe)) { throw "Multica CLI installation failed." }

& $MulticaExe config set server_url $ServerUrl --profile $Profile *> $null
if ($LASTEXITCODE -ne 0) { throw "Could not configure server_url." }
& $MulticaExe config set app_url $AppUrl --profile $Profile *> $null
if ($LASTEXITCODE -ne 0) { throw "Could not configure app_url." }

& $MulticaExe auth status --profile $Profile *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Output "Opening the interactive self-host login flow..."
    & $MulticaExe setup self-host `
        --server-url $ServerUrl `
        --app-url $AppUrl `
        --callback-host $CallbackHost `
        --profile $Profile
    if ($LASTEXITCODE -ne 0) { throw "Interactive Multica login failed." }
}

if ($IdentityEmail) {
    $AuthStatus = (& $MulticaExe auth status --profile $Profile 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Could not verify the authenticated Multica identity." }
    $IdentityMatch = [regex]::Match($AuthStatus, '(?im)^User:\s+.*\(([^()\s]+@[^()\s]+)\)\s*$')
    if (-not $IdentityMatch.Success) { throw "Could not parse the authenticated Multica email." }
    if (-not $IdentityMatch.Groups[1].Value.Equals($IdentityEmail, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Authenticated Multica email does not match IdentityEmail."
    }
}

if (-not [string]::IsNullOrWhiteSpace($Workspace)) {
    Write-Output "Verifying membership and selecting workspace '$Workspace'..."
    & $MulticaExe workspace switch $Workspace --profile $Profile
    if ($LASTEXITCODE -ne 0) {
        throw "The authenticated user is not an accepted member of workspace '$Workspace'."
    }
    & $CacheScript set -Profile $Profile -Entry "INVITATION_STATUS=accepted" *> $null
}

$Starter = Join-Path $PSScriptRoot "start-windows-runtime-client.ps1"
& $Starter -ServerUrl $ServerUrl -AppUrl $AppUrl -Profile $Profile `
    -Workspace $Workspace `
    -DeviceName $DeviceName -RuntimeName $RuntimeName `
    -MaxConcurrentTasks $MaxConcurrentTasks -AgentTimeout $AgentTimeout
if ($LASTEXITCODE -ne 0) { throw "Runtime client verification failed." }

[ordered]@{
    schema_version = 1
    status = "ready"
    phase = "runtime-client-ready"
    server_url = $ServerUrl.TrimEnd('/')
    workspace = $Workspace
    identity_email = $IdentityEmail
    tailscale_access_mode = $TailscaleAccessMode
} | ConvertTo-Json -Compress
