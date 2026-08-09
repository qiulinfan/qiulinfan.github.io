<# Start the native Windows Multica runtime client against an existing server. #>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ServerUrl,
    [string] $AppUrl = "",
    [Parameter(Mandatory)] [string] $Workspace,
    [string] $Profile = "remote",
    [string] $DeviceName = $env:COMPUTERNAME,
    [string] $RuntimeName = "",
    [ValidateRange(1, 50)] [int] $MaxConcurrentTasks = 1,
    [string] $AgentTimeout = "0s",
    [ValidateRange(10, 600)] [int] $TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"

function Assert-HttpUrl([string] $Name, [string] $Value) {
    $Parsed = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref] $Parsed) -or
        $Parsed.Scheme -notin @("http", "https") -or
        -not [string]::IsNullOrEmpty($Parsed.UserInfo)) {
        throw "$Name must be an absolute http(s) URL without embedded credentials."
    }
}

function Get-MulticaExe {
    $Installed = Join-Path $env:USERPROFILE ".multica\bin\multica.exe"
    if (Test-Path -LiteralPath $Installed) { return $Installed }
    $Command = Get-Command multica.exe -ErrorAction SilentlyContinue
    if ($Command) { return $Command.Source }
    throw "Multica CLI is not installed. Run connect-windows-runtime-client.ps1 first."
}

if ([string]::IsNullOrWhiteSpace($AppUrl)) { $AppUrl = $ServerUrl }
Assert-HttpUrl "ServerUrl" $ServerUrl
Assert-HttpUrl "AppUrl" $AppUrl
if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid Multica profile: $Profile" }
if ([string]::IsNullOrWhiteSpace($Workspace)) { throw "Workspace is required." }
if ([string]::IsNullOrWhiteSpace($DeviceName)) { throw "DeviceName cannot be empty." }
if ([string]::IsNullOrWhiteSpace($RuntimeName)) { $RuntimeName = "$DeviceName runtime" }
if ($AgentTimeout -notmatch '^(0|[0-9]+(?:ms|s|m|h))$') { throw "Invalid AgentTimeout: $AgentTimeout" }

$MulticaExe = Get-MulticaExe
$LogDirectory = Join-Path $env:LOCALAPPDATA "Multica"
$LogPath = Join-Path $LogDirectory "runtime-client-$Profile.log"
New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null

function Write-SafeLog([string] $Message) {
    $Line = "[$(Get-Date -Format o)] $Message"
    Add-Content -LiteralPath $LogPath -Value $Line -Encoding utf8
    Write-Output $Line
}

Write-SafeLog "Connecting runtime client to $ServerUrl"
try {
    & $MulticaExe config set server_url $ServerUrl --profile $Profile *> $null
    if ($LASTEXITCODE -ne 0) { throw "Could not set server_url for profile '$Profile'." }
    & $MulticaExe config set app_url $AppUrl --profile $Profile *> $null
    if ($LASTEXITCODE -ne 0) { throw "Could not set app_url for profile '$Profile'." }

    $Authenticated = $false
    for ($Attempt = 0; $Attempt -lt $TimeoutSeconds; $Attempt++) {
        & $MulticaExe auth status --profile $Profile *> $null
        if ($LASTEXITCODE -eq 0) { $Authenticated = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $Authenticated) {
        throw "Profile '$Profile' is not authenticated or the server is unavailable. Run the interactive connect script."
    }

    if (-not [string]::IsNullOrWhiteSpace($Workspace)) {
        & $MulticaExe workspace switch $Workspace --profile $Profile *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "The authenticated user is not an accepted member of workspace '$Workspace'."
        }
    }

    & $MulticaExe daemon status --profile $Profile *> $null
    if ($LASTEXITCODE -eq 0) { & $MulticaExe daemon stop --profile $Profile *> $null }
    & $MulticaExe daemon start --profile $Profile `
        --device-name $DeviceName `
        --runtime-name $RuntimeName `
        --max-concurrent-tasks $MaxConcurrentTasks `
        --agent-timeout $AgentTimeout
    if ($LASTEXITCODE -ne 0) { throw "Could not start the Windows Multica daemon." }

    $Verifier = Join-Path $PSScriptRoot "verify-runtime-client.ps1"
    $Verification = $null
    for ($Attempt = 0; $Attempt -lt $TimeoutSeconds; $Attempt++) {
        try {
            $Verification = & $Verifier -Workspace $Workspace -Profile $Profile -MulticaExe $MulticaExe
            if ($LASTEXITCODE -eq 0) { break }
        } catch { $Verification = $null }
        Start-Sleep -Seconds 1
    }
    if (-not $Verification) { throw "Multica did not report an online local runtime in the target workspace." }
    $Verification
    Write-SafeLog "Windows runtime client is online in workspace '$Workspace'."
} catch {
    Write-SafeLog "Startup failed: $($_.Exception.Message)"
    throw
}
