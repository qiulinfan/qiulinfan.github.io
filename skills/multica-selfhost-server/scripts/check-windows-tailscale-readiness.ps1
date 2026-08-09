<# Check Tailscale login and HTTPS Serve consent without opening or waiting on interactive CLI flows. #>

[CmdletBinding()]
param(
    [string] $Profile = "home",
    [ValidateRange(1, 65535)] [int] $GatewayPort = 8787,
    [ValidateRange(2, 15)] [int] $ProbeTimeoutSeconds = 5,
    [string] $TailscalePath = ""
)

$ErrorActionPreference = "Stop"
if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid profile: $Profile" }
$CacheScript = Join-Path $PSScriptRoot "profile-cache.ps1"
$ManualUrl = "https://login.tailscale.com/admin/dns"
$GatewayUrl = "http://127.0.0.1:$GatewayPort"

function Resolve-Tailscale {
    if ($TailscalePath) {
        if (-not (Test-Path -LiteralPath $TailscalePath)) { throw "Tailscale executable not found: $TailscalePath" }
        return (Resolve-Path -LiteralPath $TailscalePath).Path
    }
    $Candidates = @()
    $Command = Get-Command tailscale.exe -ErrorAction SilentlyContinue
    if ($Command) { $Candidates += $Command.Source }
    if ($env:ProgramFiles) { $Candidates += (Join-Path $env:ProgramFiles "Tailscale\tailscale.exe") }
    if (${env:ProgramFiles(x86)}) {
        $Candidates += (Join-Path ${env:ProgramFiles(x86)} "Tailscale\tailscale.exe")
    }
    $Resolved = $Candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if (-not $Resolved) {
        throw "Tailscale is not installed. Install it automatically for the detected platform, then rerun this check."
    }
    return $Resolved
}

function Invoke-HiddenTailscale {
    param([Parameter(Mandatory)] [string[]] $Arguments, [Parameter(Mandatory)] [int] $TimeoutSeconds)

    $StartInfo = [Diagnostics.ProcessStartInfo]::new()
    if ([IO.Path]::GetExtension($script:Tailscale).Equals(".ps1", [StringComparison]::OrdinalIgnoreCase)) {
        $StartInfo.FileName = (Get-Command pwsh.exe -ErrorAction Stop).Source
        foreach ($Prefix in @("-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", $script:Tailscale)) {
            [void]$StartInfo.ArgumentList.Add($Prefix)
        }
    } else {
        $StartInfo.FileName = $script:Tailscale
    }
    foreach ($Argument in $Arguments) { [void]$StartInfo.ArgumentList.Add($Argument) }
    $StartInfo.UseShellExecute = $false
    $StartInfo.CreateNoWindow = $true
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true

    $Process = [Diagnostics.Process]::new()
    $Process.StartInfo = $StartInfo
    try {
        if (-not $Process.Start()) { throw "Could not start the Tailscale readiness probe." }
        $StandardOutput = $Process.StandardOutput.ReadToEndAsync()
        $StandardError = $Process.StandardError.ReadToEndAsync()
        $Finished = $Process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $Finished) {
            try { $Process.Kill($true) } catch { try { $Process.Kill() } catch {} }
            $Process.WaitForExit()
        }
        $OutputText = $StandardOutput.GetAwaiter().GetResult()
        [void]$StandardError.GetAwaiter().GetResult()
        return [pscustomobject]@{
            timed_out = (-not $Finished)
            exit_code = if ($Finished) { $Process.ExitCode } else { $null }
            stdout = $OutputText
        }
    } finally {
        $Process.Dispose()
    }
}

function Write-ManualResult {
    & $CacheScript set -Profile $Profile -Entry @(
        "ONBOARDING_PHASE=tailscale-action-required", "TAILSCALE_SERVE_APPROVED=false"
    ) *> $null
    [ordered]@{
        schema_version = 1
        status = "manual_action_required"
        action = "tailscale_login_and_https"
        phase = "tailscale-action-required"
        manual_url = $ManualUrl
        instructions = @(
            "打开 Tailscale 客户端，用自己的账号登录，并确认本机显示 Connected。",
            "在已登录的外部浏览器打开 Tailscale DNS 页面，启用 MagicDNS 和 HTTPS Certificates。",
            '完成后再次调用 $multica-selfhost-server，并说“继续部署”。'
        )
    } | ConvertTo-Json -Depth 5 -Compress
}

$script:Tailscale = Resolve-Tailscale
$StatusProbe = Invoke-HiddenTailscale -Arguments @("status", "--json") -TimeoutSeconds $ProbeTimeoutSeconds
if ($StatusProbe.timed_out -or $StatusProbe.exit_code -ne 0 -or -not $StatusProbe.stdout) {
    Write-ManualResult
    return
}
try { $Status = $StatusProbe.stdout | ConvertFrom-Json } catch {
    Write-ManualResult
    return
}
$DnsName = [string]$Status.Self.DNSName
$DnsName = $DnsName.Trim().TrimEnd('.')
if ($Status.BackendState -ne "Running" -or $DnsName -notmatch '^[A-Za-z0-9.-]+\.ts\.net$') {
    Write-ManualResult
    return
}

$ServeProbe = Invoke-HiddenTailscale -Arguments @("serve", "--bg", "--yes", $GatewayUrl) `
    -TimeoutSeconds $ProbeTimeoutSeconds
if ($ServeProbe.timed_out -or $ServeProbe.exit_code -ne 0) {
    Write-ManualResult
    return
}

$PublishedUrl = "https://$DnsName"
& $CacheScript set -Profile $Profile -Entry @(
    "PUBLISHED_URL=$PublishedUrl", "TAILSCALE_SERVE_APPROVED=true", "ONBOARDING_PHASE=tailscale-ready"
) *> $null
[ordered]@{
    schema_version = 1
    status = "ready"
    action = "continue_deployment"
    phase = "tailscale-ready"
    published_url = $PublishedUrl
    gateway_url = $GatewayUrl
} | ConvertTo-Json -Compress
