<# Open the first-owner Web UI and return immediately at the identity boundary. #>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $AppUrl,
    [Parameter(Mandatory)] [string] $OwnerEmail,
    [string] $Profile = "home",
    [switch] $NoOpen
)

$ErrorActionPreference = "Stop"
if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid profile: $Profile" }
if ($OwnerEmail -notmatch '^[^@\s,]+@[^@\s,]+\.[^@\s,]+$') { throw "Invalid owner email." }
$Parsed = $null
if (-not [Uri]::TryCreate($AppUrl, [UriKind]::Absolute, [ref]$Parsed) -or
    $Parsed.Scheme -notin @("http", "https") -or $Parsed.UserInfo) {
    throw "AppUrl must be an absolute http(s) URL without embedded credentials."
}
$AppUrl = $AppUrl.TrimEnd('/')
$CacheScript = Join-Path $PSScriptRoot "profile-cache.ps1"
& $CacheScript set -Profile $Profile -Entry @(
    "OWNER_EMAIL=$OwnerEmail", "ONBOARDING_PHASE=owner-registration-required"
) *> $null
if (-not $NoOpen) { Start-Process $AppUrl }
$Cache = (& $CacheScript show -Profile $Profile) | ConvertFrom-Json
[ordered]@{
    schema_version = 1
    status = "manual_action_required"
    action = "owner_registration"
    phase = "owner-registration-required"
    app_url = $AppUrl
    owner_email = $OwnerEmail
    workspace = [string]$Cache.values.WORKSPACE_SLUG
    instructions = @(
        "在已打开的 WebUI 中使用 owner 邮箱完成注册或登录，并创建缓存中的 workspace。",
        "只需亲自完成浏览器、邮箱或 OAuth 身份验证；不要执行命令。",
        '进入 workspace 后再次调用 $multica-selfhost-server，并说“继续完成首个 runtime”。'
    )
} | ConvertTo-Json -Depth 5 -Compress
