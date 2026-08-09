<# Write a non-secret client onboarding receipt for one invited member. #>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $MemberEmail,
    [ValidateSet("same-tailnet", "shared-machine")] [string] $TailscaleAccessMode,
    [ValidateSet("pending", "accepted", "reachable")] [string] $TailscaleAccessStatus = "pending",
    [ValidateSet("pending", "accepted")] [string] $MulticaInvitationStatus = "pending",
    [string] $Profile = "home"
)

$ErrorActionPreference = "Stop"
if ($MemberEmail -notmatch '^[^@\s,]+@[^@\s,]+\.[^@\s,]+$') { throw "Invalid member email." }
$Cache = (& (Join-Path $PSScriptRoot "profile-cache.ps1") show -Profile $Profile) | ConvertFrom-Json
$ServerUrl = [string]$Cache.values.PUBLISHED_URL
$Workspace = [string]$Cache.values.WORKSPACE_SLUG
if ($ServerUrl -notmatch '^https://[A-Za-z0-9.-]+\.ts\.net$' -or -not $Workspace) {
    throw "A published Tailscale URL and workspace slug are required."
}
if ($Workspace -notmatch '^[A-Za-z0-9._-]+$') { throw "Unsafe workspace slug." }
$Directory = Join-Path $env:USERPROFILE ".multica\selfhost-server\$Profile\handoffs"
New-Item -ItemType Directory -Force -Path $Directory | Out-Null
$SafeName = $MemberEmail.ToLowerInvariant() -replace '[^a-z0-9._-]', '_'
$Path = Join-Path $Directory "$SafeName.json"
$Receipt = [ordered]@{
    schema_version = 1
    server_url = $ServerUrl
    app_url = $ServerUrl
    workspace = $Workspace
    member_email = $MemberEmail.ToLowerInvariant()
    tailscale_access_mode = $TailscaleAccessMode
    tailscale_access_status = $TailscaleAccessStatus
    multica_invitation_status = $MulticaInvitationStatus
    contains_credentials = $false
    updated_at = (Get-Date).ToUniversalTime().ToString("o")
}
$Temporary = "$Path.tmp.$PID"
$Receipt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $Temporary -Encoding utf8
Move-Item -LiteralPath $Temporary -Destination $Path -Force
$Receipt | ConvertTo-Json -Depth 4
