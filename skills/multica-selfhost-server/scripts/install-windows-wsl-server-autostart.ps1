<# Register the WSL self-host server starter as a current-user logon task. #>

[CmdletBinding()]
param(
    [string] $WslDistro = "Ubuntu-26.04",
    [string] $LinuxRepo = "",
    [string] $Profile = "home",
    [string] $PublishedUrl = "",
    [ValidateRange(1, 65535)] [int] $GatewayPort = 8787,
    [string] $TaskName = ""
)

$ErrorActionPreference = "Stop"
if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid Multica profile: $Profile" }
if ([string]::IsNullOrWhiteSpace($TaskName)) { $TaskName = "Multica-Server-$Profile" }
if ($TaskName -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid scheduled task name: $TaskName" }
foreach ($Value in @($WslDistro, $LinuxRepo, $Profile, $PublishedUrl)) {
    if ($Value -match '["\r\n]') { throw "Task arguments cannot contain quotes or newlines." }
}

$Starter = Join-Path $PSScriptRoot "start-windows-wsl-server.ps1"
if (-not (Test-Path -LiteralPath $Starter)) { throw "Starter not found: $Starter" }
$StarterArguments = @{
    WslDistro = $WslDistro; LinuxRepo = $LinuxRepo; Profile = $Profile; GatewayPort = $GatewayPort
}
if ($PublishedUrl) { $StarterArguments.PublishedUrl = $PublishedUrl }
& $Starter @StarterArguments
if ($LASTEXITCODE -ne 0) { throw "Server restart verification failed." }
& (Join-Path $PSScriptRoot "profile-cache.ps1") set -Profile $Profile `
    -Entry "SERVER_AUTOSTART_APPROVED=true" *> $null

$PwshAlias = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\pwsh.exe"
$PwshExe = if (Test-Path -LiteralPath $PwshAlias) { $PwshAlias }
else { (Get-Command pwsh.exe -ErrorAction Stop).Source }
$Parts = @(
    '-NoProfile', '-WindowStyle Hidden', '-ExecutionPolicy Bypass', "-File `"$Starter`"",
    "-WslDistro `"$WslDistro`"", "-Profile `"$Profile`"", "-GatewayPort $GatewayPort"
)
if ($LinuxRepo) { $Parts += "-LinuxRepo `"$LinuxRepo`"" }
if ($PublishedUrl) { $Parts += "-PublishedUrl `"$PublishedUrl`"" }
$Parts += '-KeepAlive'
$Action = New-ScheduledTaskAction -Execute $PwshExe -Argument ($Parts -join ' ')
$UserId = "$env:USERDOMAIN\$env:USERNAME"
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $UserId
$Principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType Interactive -RunLevel Limited
$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Seconds 0) `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
    -Principal $Principal -Settings $Settings `
    -Description "Start the WSL Multica self-host server after user logon." -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName
Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State, TaskPath
