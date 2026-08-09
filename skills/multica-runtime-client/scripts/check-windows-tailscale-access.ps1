<# Verify that this Windows device can reach a private Multica server through Tailscale. #>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ServerUrl,
    [string] $Profile = "remote",
    [ValidateSet("same-tailnet", "shared-machine")] [string] $AccessMode = "same-tailnet",
    [ValidateRange(2, 15)] [int] $TimeoutSeconds = 5
)

$ErrorActionPreference = "Stop"
$Parsed = $null
if (-not [Uri]::TryCreate($ServerUrl, [UriKind]::Absolute, [ref]$Parsed) -or
    $Parsed.Scheme -ne "https" -or $Parsed.UserInfo -or $Parsed.Port -ne 443 -or
    $Parsed.AbsolutePath -ne "/" -or $Parsed.Query -or $Parsed.Fragment -or
    $Parsed.Host -notmatch '^[A-Za-z0-9.-]+\.ts\.net$') {
    throw "ServerUrl must be a credential-free Tailscale HTTPS origin ending in .ts.net."
}
if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid profile: $Profile" }
$CacheScript = Join-Path $PSScriptRoot "profile-cache.ps1"

function Write-ManualResult([string] $Reason) {
    & $CacheScript set -Profile $Profile -Entry @(
        "TAILSCALE_ACCESS_MODE=$AccessMode", "TAILSCALE_ACCESS_STATUS=pending"
    ) *> $null
    [ordered]@{
        schema_version = 1
        status = "manual_action_required"
        phase = "tailscale-access-required"
        action = if ($AccessMode -eq "same-tailnet") { "accept_tailnet_invite" } else { "accept_machine_share" }
        reason = $Reason
        background_work = $false
        resume_hint = "继续连接客户端"
    } | ConvertTo-Json -Compress
    exit 7
}

$TailscaleCommand = Get-Command tailscale.exe -ErrorAction SilentlyContinue
$TailscalePath = if ($TailscaleCommand) { $TailscaleCommand.Source } else { "" }
if (-not $TailscalePath) {
    $Candidate = Join-Path $env:ProgramFiles "Tailscale\tailscale.exe"
    if (Test-Path -LiteralPath $Candidate) { $TailscalePath = $Candidate }
}
if (-not $TailscalePath) { Write-ManualResult "tailscale_not_installed" }

try {
    $Status = (& $TailscalePath status --json 2>$null) | ConvertFrom-Json
} catch { Write-ManualResult "tailscale_not_authenticated" }
if ($Status.BackendState -ne "Running") { Write-ManualResult "tailscale_not_connected" }

try {
    $Response = Invoke-WebRequest "$($ServerUrl.TrimEnd('/'))/api/config" -TimeoutSec $TimeoutSeconds
    if ($Response.StatusCode -ne 200) { Write-ManualResult "server_not_reachable" }
} catch { Write-ManualResult "server_not_reachable_or_acl_denied" }

& $CacheScript set -Profile $Profile -Entry @(
    "TAILSCALE_ACCESS_MODE=$AccessMode", "TAILSCALE_ACCESS_STATUS=reachable"
) *> $null
[ordered]@{
    schema_version = 1
    status = "ready"
    phase = "tailscale-access-ready"
    access_mode = $AccessMode
    server_url = $ServerUrl.TrimEnd('/')
} | ConvertTo-Json -Compress
