<# Apply cached signup and workspace-creation policy to a Multica server checkout. #>

[CmdletBinding(DefaultParameterSetName = "Wsl")]
param(
    [string] $Profile = "home",
    [Parameter(ParameterSetName = "Wsl")] [string] $WslDistro = "",
    [Parameter(ParameterSetName = "Wsl")] [string] $LinuxRepo = "",
    [Parameter(ParameterSetName = "Native", Mandatory)] [string] $ServerRepo,
    [switch] $Recreate
)

$ErrorActionPreference = "Stop"
$CacheScript = Join-Path $PSScriptRoot "profile-cache.ps1"
$CacheResult = (& $CacheScript show -Profile $Profile) | ConvertFrom-Json
if (-not $CacheResult.exists) { throw "No cached server profile exists for '$Profile'." }
$Values = $CacheResult.values

$AllowedEmails = [string]$Values.ALLOWED_EMAILS
$OwnerEmail = [string]$Values.OWNER_EMAIL
if ([string]::IsNullOrWhiteSpace($AllowedEmails)) { throw "Cached ALLOWED_EMAILS is required." }
if ($OwnerEmail -and $OwnerEmail -notin @($AllowedEmails.Split(',') | ForEach-Object { $_.Trim() })) {
    throw "OWNER_EMAIL must also appear in ALLOWED_EMAILS."
}
$AllowSignup = if ($null -ne $Values.ALLOW_SIGNUP) { [string]$Values.ALLOW_SIGNUP } else { "true" }
$DisableWorkspaceCreation = if ($null -ne $Values.DISABLE_WORKSPACE_CREATION) {
    [string]$Values.DISABLE_WORKSPACE_CREATION
} else { "false" }
$Updates = [ordered]@{
    ALLOW_SIGNUP = $AllowSignup
    ALLOWED_EMAILS = $AllowedEmails
    DISABLE_WORKSPACE_CREATION = $DisableWorkspaceCreation
}

function Set-EnvironmentFile([string] $EnvironmentPath) {
    if (-not (Test-Path -LiteralPath $EnvironmentPath)) { throw "Multica .env not found: $EnvironmentPath" }
    $Lines = [Collections.Generic.List[string]]::new()
    foreach ($Line in [IO.File]::ReadAllLines($EnvironmentPath)) { $Lines.Add($Line) }
    foreach ($Key in $Updates.Keys) {
        $Found = $false
        for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
            if ($Lines[$Index] -match "^$([regex]::Escape($Key))=") {
                $Lines[$Index] = "$Key=$($Updates[$Key])"
                $Found = $true
                break
            }
        }
        if (-not $Found) { $Lines.Add("$Key=$($Updates[$Key])") }
    }
    $Temporary = "$EnvironmentPath.tmp.$PID"
    [IO.File]::WriteAllLines($Temporary, $Lines, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $Temporary -Destination $EnvironmentPath -Force
}

if ($PSCmdlet.ParameterSetName -eq "Native") {
    $ResolvedRepo = (Resolve-Path -LiteralPath $ServerRepo).Path
    $EnvironmentPath = Join-Path $ResolvedRepo ".env"
    Set-EnvironmentFile $EnvironmentPath
    if ($Recreate) {
        & docker compose -f (Join-Path $ResolvedRepo "docker-compose.selfhost.yml") up -d
        if ($LASTEXITCODE -ne 0) { throw "Could not recreate the Multica services." }
    }
} else {
    if ([string]::IsNullOrWhiteSpace($WslDistro)) { $WslDistro = [string]$Values.WSL_DISTRO }
    if ([string]::IsNullOrWhiteSpace($LinuxRepo)) { $LinuxRepo = [string]$Values.LINUX_REPO }
    if ($WslDistro -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid WSL distribution." }
    if ($LinuxRepo -notmatch '^/[A-Za-z0-9._/-]+$') { throw "Invalid LinuxRepo." }
    $EnvironmentPath = "\\wsl.localhost\$WslDistro$($LinuxRepo.Replace('/', '\'))\.env"
    Set-EnvironmentFile $EnvironmentPath
    & wsl.exe -d $WslDistro --exec chmod 600 "$LinuxRepo/.env"
    if ($LASTEXITCODE -ne 0) { throw "Could not restrict permissions on the server .env." }
    if ($Recreate) {
        & wsl.exe -d $WslDistro --exec docker compose `
            -f "$LinuxRepo/docker-compose.selfhost.yml" up -d
        if ($LASTEXITCODE -ne 0) { throw "Could not recreate the Multica services." }
    }
}

[ordered]@{
    profile = $Profile
    allowed_email_count = @($AllowedEmails.Split(',')).Count
    allow_signup = $AllowSignup
    disable_workspace_creation = $DisableWorkspaceCreation
    recreated = [bool]$Recreate
} | ConvertTo-Json
