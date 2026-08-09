<# Manage the git-ignored, non-secret local profile cache for this Skill. #>

[CmdletBinding()]
param(
    [Parameter(Position = 0)] [ValidateSet("show", "set", "path")] [string] $Action = "show",
    [string] $Profile = "home",
    [string[]] $Entry = @()
)

$ErrorActionPreference = "Stop"
$WritableKeys = @(
    "SERVER_URL", "APP_URL", "WORKSPACE", "IDENTITY_EMAIL", "INVITATION_STATUS", "PLATFORM",
    "DEVICE_NAME", "RUNTIME_NAME", "MAX_CONCURRENT_TASKS",
    "TAILSCALE_ACCESS_MODE", "TAILSCALE_ACCESS_STATUS",
    "AGENT_TIMEOUT", "WORKSPACE_AGENT_ACCESS_APPROVED", "AUTOSTART_APPROVED"
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
        "IDENTITY_EMAIL" {
            if ($Value -notmatch '^[^@\s,]+@[^@\s,]+\.[^@\s,]+$') { throw "Invalid IDENTITY_EMAIL." }
        }
        { $_ -in @("SERVER_URL", "APP_URL") } {
            $Parsed = $null
            if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$Parsed) -or
                $Parsed.Scheme -notin @("http", "https") -or $Parsed.UserInfo) {
                throw "$Key must be an absolute http(s) URL without embedded credentials."
            }
            $Value = $Value.TrimEnd('/')
        }
        "INVITATION_STATUS" {
            if ($Value -notin @("unknown", "pending", "accepted")) {
                throw "INVITATION_STATUS must be unknown, pending, or accepted."
            }
        }
        "PLATFORM" {
            if ($Value -notin @("windows", "macos", "linux")) {
                throw "PLATFORM must be windows, macos, or linux."
            }
        }
        "TAILSCALE_ACCESS_MODE" {
            if ($Value -notin @("same-tailnet", "shared-machine")) {
                throw "TAILSCALE_ACCESS_MODE must be same-tailnet or shared-machine."
            }
        }
        "TAILSCALE_ACCESS_STATUS" {
            if ($Value -notin @("unknown", "pending", "accepted", "reachable")) {
                throw "Invalid TAILSCALE_ACCESS_STATUS."
            }
        }
        { $_ -in @("WORKSPACE_AGENT_ACCESS_APPROVED", "AUTOSTART_APPROVED") } {
            if ($Value -notin @("true", "false")) { throw "$Key must be true or false." }
        }
        "MAX_CONCURRENT_TASKS" {
            $Number = 0
            if (-not [int]::TryParse($Value, [ref]$Number) -or $Number -lt 1 -or $Number -gt 50) {
                throw "MAX_CONCURRENT_TASKS must be between 1 and 50."
            }
        }
        "AGENT_TIMEOUT" {
            if ($Value -notmatch '^(0|[0-9]+(?:ms|s|m|h))$') { throw "Invalid AGENT_TIMEOUT." }
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
