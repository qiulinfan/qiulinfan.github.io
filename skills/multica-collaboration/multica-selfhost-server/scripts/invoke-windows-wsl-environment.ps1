<# Forward stop/export/restore lifecycle operations into the WSL Docker host. #>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet("stop", "export", "restore")]
    [string] $Action,
    [string] $WslDistro = "Ubuntu-26.04",
    [string] $LinuxRepo = "",
    [string] $Profile = "home",
    [string] $OutputRoot = "",
    [string] $AgeRecipient = "",
    [string] $ArchivePath = "",
    [string] $AgeIdentityFile = "",
    [switch] $ConfirmRestore
)

$ErrorActionPreference = "Stop"
if ($WslDistro -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid WSL distribution: $WslDistro" }
if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid Multica profile: $Profile" }
& wsl.exe -d $WslDistro --exec true
if ($LASTEXITCODE -ne 0) { throw "WSL distribution is unavailable: $WslDistro" }
if ([string]::IsNullOrWhiteSpace($LinuxRepo)) {
    $WslUser = (& wsl.exe -d $WslDistro --exec id -un | Select-Object -Last 1).Trim()
    if ($LASTEXITCODE -ne 0 -or $WslUser -notmatch '^[a-z_][a-z0-9_-]*$') {
        throw "Could not resolve the WSL user."
    }
    $LinuxRepo = "/home/$WslUser/multica"
}
if ($LinuxRepo -notmatch '^/[A-Za-z0-9._/-]+$') { throw "Invalid WSL repository path: $LinuxRepo" }

function Convert-ToWslPath([string] $Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "A Windows path is required." }
    $Resolved = (Resolve-Path -LiteralPath $Path).Path
    $WslPath = (& wsl.exe -d $WslDistro --exec wslpath -a $Resolved | Select-Object -Last 1).Trim()
    if ($LASTEXITCODE -ne 0 -or $WslPath -notmatch '^/') { throw "Could not translate path into WSL: $Resolved" }
    return $WslPath
}

$ScriptName = switch ($Action) {
    "stop" { "stop-unix-server.sh" }
    "export" { "export-unix-server-environment.sh" }
    "restore" { "restore-unix-server-environment.sh" }
}
$ScriptPath = Convert-ToWslPath (Join-Path $PSScriptRoot $ScriptName)
$Arguments = @("-d", $WslDistro, "--exec", "/bin/sh", $ScriptPath, $LinuxRepo, $Profile)

switch ($Action) {
    "export" {
        if ([string]::IsNullOrWhiteSpace($OutputRoot)) { throw "Export requires -OutputRoot." }
        if ([string]::IsNullOrWhiteSpace($AgeRecipient)) { throw "Export requires -AgeRecipient." }
        if (-not (Test-Path -LiteralPath $OutputRoot)) {
            New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
        }
        $Arguments += @(Convert-ToWslPath $OutputRoot, $AgeRecipient)
    }
    "restore" {
        if (-not $ConfirmRestore) { throw "Restore requires -ConfirmRestore after explicit recovery authorization." }
        $Arguments += @(
            (Convert-ToWslPath $ArchivePath),
            (Convert-ToWslPath $AgeIdentityFile),
            "RESTORE_EMPTY_TARGET"
        )
    }
}

& wsl.exe @Arguments
if ($LASTEXITCODE -ne 0) { throw "WSL lifecycle operation '$Action' failed with exit code $LASTEXITCODE." }
