<# Register the Windows runtime client as a current-user interactive logon task. #>

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
    [string] $TaskName = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($AppUrl)) { $AppUrl = $ServerUrl }
if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid Multica profile: $Profile" }
if ([string]::IsNullOrWhiteSpace($Workspace)) { throw "Workspace is required." }
if ([string]::IsNullOrWhiteSpace($RuntimeName)) { $RuntimeName = "$DeviceName runtime" }
if ([string]::IsNullOrWhiteSpace($TaskName)) { $TaskName = "Multica-RuntimeClient-$Profile" }
if ($TaskName -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid scheduled task name: $TaskName" }

foreach ($Value in @($ServerUrl, $AppUrl, $Workspace, $DeviceName, $RuntimeName, $AgentTimeout)) {
    if ($Value -match '["\r\n]') { throw "Task arguments cannot contain quotes or newlines." }
}

$Starter = Join-Path $PSScriptRoot "start-windows-runtime-client.ps1"
if (-not (Test-Path -LiteralPath $Starter)) { throw "Starter not found: $Starter" }
Write-Output "Verifying the runtime client before registering persistence..."
& $Starter -ServerUrl $ServerUrl -AppUrl $AppUrl -Profile $Profile `
    -Workspace $Workspace `
    -DeviceName $DeviceName -RuntimeName $RuntimeName `
    -MaxConcurrentTasks $MaxConcurrentTasks -AgentTimeout $AgentTimeout
if ($LASTEXITCODE -ne 0) { throw "Runtime client verification failed." }
& (Join-Path $PSScriptRoot "profile-cache.ps1") set -Profile $Profile `
    -Entry "AUTOSTART_APPROVED=true" *> $null

$PwshAlias = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\pwsh.exe"
$PwshExe = if (Test-Path -LiteralPath $PwshAlias) { $PwshAlias }
else { (Get-Command pwsh.exe -ErrorAction Stop).Source }
$Arguments = @(
    '-NoProfile'
    '-WindowStyle Hidden'
    '-ExecutionPolicy Bypass'
    "-File `"$Starter`""
    "-ServerUrl `"$ServerUrl`""
    "-AppUrl `"$AppUrl`""
    "-Profile `"$Profile`""
    "-Workspace `"$Workspace`""
    "-DeviceName `"$DeviceName`""
    "-RuntimeName `"$RuntimeName`""
    "-MaxConcurrentTasks $MaxConcurrentTasks"
    "-AgentTimeout `"$AgentTimeout`""
) -join ' '

$UserId = "$env:USERDOMAIN\$env:USERNAME"
$Action = New-ScheduledTaskAction -Execute $PwshExe -Argument $Arguments
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $UserId
$Principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType Interactive -RunLevel Limited
$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
    -Principal $Principal -Settings $Settings `
    -Description "Start this Windows machine as a Multica runtime client after user logon." `
    -Force | Out-Null

Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State, TaskPath
Write-Output "Runtime client autostart registered for $UserId without storing a password."
