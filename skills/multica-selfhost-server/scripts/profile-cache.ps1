<# Manage the git-ignored, non-secret local profile cache for this Skill. #>

[CmdletBinding()]
param(
    [Parameter(Position = 0)] [ValidateSet("show", "set", "path")] [string] $Action = "show",
    [string] $Profile = "home",
    [string[]] $Entry = @()
)

$ErrorActionPreference = "Stop"
$WritableKeys = @(
    "TOPOLOGY", "WSL_DISTRO", "LINUX_REPO", "SERVER_REPO", "GATEWAY_PORT",
    "PUBLISHED_URL", "OWNER_EMAIL", "ALLOWED_EMAILS", "INVITED_EMAILS", "ACCEPTED_EMAILS", "ALLOW_SIGNUP",
    "DISABLE_WORKSPACE_CREATION", "ONBOARDING_PHASE", "WORKSPACE_NAME", "WORKSPACE_SLUG",
    "ISSUE_PREFIX", "DEVICE_NAME", "RUNTIME_NAME",
    "MAX_CONCURRENT_TASKS", "TAILSCALE_SERVE_APPROVED",
    "WORKSPACE_AGENT_ACCESS_APPROVED", "SERVER_AUTOSTART_APPROVED",
    "RUNTIME_AUTOSTART_APPROVED"
)
$DeprecatedKeys = @("PROVIDER")
$InternalKeys = @("CACHE_SCHEMA_VERSION", "PROFILE", "UPDATED_AT")
$OrderedKeys = $InternalKeys + $WritableKeys

if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid profile: $Profile" }
$SkillRoot = Split-Path -Parent $PSScriptRoot
$IgnorePath = Join-Path $SkillRoot ".gitignore"
if (-not (Test-Path -LiteralPath $IgnorePath) -or
    -not (Select-String -LiteralPath $IgnorePath -Pattern '^\.cache/$' -Quiet)) {
    throw "Refusing to write cache until $IgnorePath ignores .cache/."
}
$CacheDirectory = Join-Path $SkillRoot ".cache\$Profile"
$CachePath = Join-Path $CacheDirectory "profile.env"

function Read-Cache {
    $Values = [ordered]@{}
    if (-not (Test-Path -LiteralPath $CachePath)) { return $Values }
    foreach ($Line in [IO.File]::ReadAllLines($CachePath)) {
        if ([string]::IsNullOrWhiteSpace($Line) -or $Line.StartsWith("#")) { continue }
        $Separator = $Line.IndexOf('=')
        if ($Separator -lt 1) { throw "Malformed cache line in $CachePath" }
        $Key = $Line.Substring(0, $Separator)
        if ($Key -in $DeprecatedKeys) { continue }
        if ($Key -notin $OrderedKeys) { throw "Unknown cache key: $Key" }
        $Values[$Key] = $Line.Substring($Separator + 1)
    }
    return $Values
}

function Normalize-Value([string] $Key, [string] $Value) {
    if ($Value -match "[`r`n`0]") { throw "$Key cannot contain control characters." }
    if ($Value -match '(?i)(?:^|[?;&\s])(?:token|pat|password|cookie|api[_-]?key|secret)=' -or
        $Value -match '(?i)(?:sk-|ghp_|pat_)[A-Za-z0-9_-]{12,}') {
        throw "$Key looks like it contains a credential; credentials are forbidden in the Skill cache."
    }
    $Value = $Value.Trim()
    switch ($Key) {
        "TOPOLOGY" {
            if ($Value -notin @("windows-wsl", "windows-native", "macos", "linux")) {
                throw "TOPOLOGY must be windows-wsl, windows-native, macos, or linux."
            }
        }
        "ONBOARDING_PHASE" {
            if ($Value -notin @(
                "tailscale-action-required", "tailscale-ready", "server-ready",
                "owner-registration-required", "cluster-finalizing", "complete"
            )) {
                throw "Invalid ONBOARDING_PHASE."
            }
        }
        { $_ -in @("OWNER_EMAIL") } {
            if ($Value -notmatch '^[^@\s,]+@[^@\s,]+\.[^@\s,]+$') { throw "Invalid email for $Key." }
        }
        { $_ -in @("ALLOWED_EMAILS", "INVITED_EMAILS", "ACCEPTED_EMAILS") } {
            $Emails = @($Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            if ($Key -eq "ALLOWED_EMAILS" -and $Emails.Count -eq 0) { throw "ALLOWED_EMAILS cannot be empty." }
            foreach ($Email in $Emails) {
                if ($Email -notmatch '^[^@\s,]+@[^@\s,]+\.[^@\s,]+$') { throw "Invalid email in $Key." }
            }
            $Value = (@($Emails | Select-Object -Unique) -join ',')
        }
        { $_ -in @("PUBLISHED_URL") -and $Value } {
            $Parsed = $null
            if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$Parsed) -or
                $Parsed.Scheme -notin @("http", "https") -or $Parsed.UserInfo) {
                throw "$Key must be an absolute http(s) URL without embedded credentials."
            }
            $Value = $Value.TrimEnd('/')
        }
        { $_ -in @("ALLOW_SIGNUP", "DISABLE_WORKSPACE_CREATION", "TAILSCALE_SERVE_APPROVED",
                    "WORKSPACE_AGENT_ACCESS_APPROVED", "SERVER_AUTOSTART_APPROVED",
                    "RUNTIME_AUTOSTART_APPROVED") } {
            if ($Value -notin @("true", "false")) { throw "$Key must be true or false." }
        }
        "GATEWAY_PORT" {
            $Number = 0
            if (-not [int]::TryParse($Value, [ref]$Number) -or $Number -lt 1 -or $Number -gt 65535) {
                throw "GATEWAY_PORT must be between 1 and 65535."
            }
        }
        "MAX_CONCURRENT_TASKS" {
            $Number = 0
            if (-not [int]::TryParse($Value, [ref]$Number) -or $Number -lt 1 -or $Number -gt 50) {
                throw "MAX_CONCURRENT_TASKS must be between 1 and 50."
            }
        }
    }
    return $Value
}

function Write-Cache([System.Collections.IDictionary] $Values) {
    New-Item -ItemType Directory -Force -Path $CacheDirectory | Out-Null
    $Values["CACHE_SCHEMA_VERSION"] = "1"
    $Values["PROFILE"] = $Profile
    $Values["UPDATED_AT"] = (Get-Date).ToUniversalTime().ToString("o")
    $Lines = foreach ($Key in $OrderedKeys) {
        if ($Values.Contains($Key)) { "$Key=$($Values[$Key])" }
    }
    $Temporary = "$CachePath.tmp.$PID"
    [IO.File]::WriteAllLines($Temporary, $Lines, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $Temporary -Destination $CachePath -Force
}

switch ($Action) {
    "path" { $CachePath }
    "show" {
        $Values = Read-Cache
        [ordered]@{ cache_path = $CachePath; exists = (Test-Path -LiteralPath $CachePath); values = $Values } |
            ConvertTo-Json -Depth 5
    }
    "set" {
        if ($Entry.Count -eq 0) { throw "Pass one or more KEY=VALUE entries." }
        $Values = Read-Cache
        foreach ($Item in $Entry) {
            $Separator = $Item.IndexOf('=')
            if ($Separator -lt 1) { throw "Entry must use KEY=VALUE: $Item" }
            $Key = $Item.Substring(0, $Separator).Trim().ToUpperInvariant()
            if ($Key -notin $WritableKeys) { throw "Cache key is not allowed: $Key" }
            $Values[$Key] = Normalize-Value $Key $Item.Substring($Separator + 1)
        }
        Write-Cache $Values
        & $PSCommandPath show -Profile $Profile
    }
}
