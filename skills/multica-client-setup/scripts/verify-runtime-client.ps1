<# Correlate the selected workspace, local daemon, and Multica-detected online runtimes. #>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Workspace,
    [string] $Profile = "remote",
    [string] $MulticaExe = "multica.exe"
)

$ErrorActionPreference = "Stop"
$WorkspaceState = (& $MulticaExe workspace get $Workspace --profile $Profile --output json 2>$null) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $WorkspaceState.id) { throw "Could not resolve target workspace '$Workspace'." }
$DaemonState = (& $MulticaExe daemon status --profile $Profile --output json 2>$null) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $DaemonState.status -ne "running" -or -not $DaemonState.daemon_id) {
    throw "The local Multica daemon is not running."
}
$WorkspaceDaemonState = @($DaemonState.workspaces | Where-Object { $_.id -eq $WorkspaceState.id })
if ($WorkspaceDaemonState.Count -ne 1) { throw "The local daemon is not registered in the target workspace." }
$LocalRuntimeIds = @($WorkspaceDaemonState[0].runtimes)
if ($LocalRuntimeIds.Count -eq 0) { throw "Multica did not detect any local runtimes in the target workspace." }
$Runtimes = @((& $MulticaExe runtime list --profile $Profile --output json 2>$null) | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0) { throw "Could not list runtimes." }
$Online = @($Runtimes | Where-Object {
    $_.id -in $LocalRuntimeIds -and $_.daemon_id -eq $DaemonState.daemon_id -and
    $_.workspace_id -eq $WorkspaceState.id -and $_.status -eq "online"
})
if ($Online.Count -eq 0) { throw "No Multica-detected local runtime is online in the target workspace." }

[ordered]@{
    schema_version = 1
    status = "ready"
    workspace_id = [string]$WorkspaceState.id
    workspace_slug = [string]$WorkspaceState.slug
    daemon_id = [string]$DaemonState.daemon_id
    runtime_ids = @($Online.id)
    runtime_count = $Online.Count
} | ConvertTo-Json -Depth 5
