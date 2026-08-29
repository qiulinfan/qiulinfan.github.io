<# Start only the Multica self-host server stack inside WSL Docker Engine. #>

[CmdletBinding()]
param(
    [string] $WslDistro = "Ubuntu-26.04",
    [string] $LinuxRepo = "",
    [string] $Profile = "home",
    [string] $PublishedUrl = "",
    [ValidateRange(1, 65535)] [int] $GatewayPort = 8787,
    [ValidateRange(10, 600)] [int] $TimeoutSeconds = 120,
    [switch] $KeepAlive
)

$ErrorActionPreference = "Stop"
if ($WslDistro -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid WSL distribution: $WslDistro" }
if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid Multica profile: $Profile" }
if (-not [string]::IsNullOrWhiteSpace($PublishedUrl)) {
    $Parsed = $null
    if (-not [Uri]::TryCreate($PublishedUrl, [UriKind]::Absolute, [ref] $Parsed) -or
        $Parsed.Scheme -notin @("http", "https") -or
        -not [string]::IsNullOrEmpty($Parsed.UserInfo)) {
        throw "PublishedUrl must be an absolute http(s) URL without embedded credentials."
    }
    $PublishedUrl = $PublishedUrl.TrimEnd('/')
}

if ([string]::IsNullOrWhiteSpace($LinuxRepo)) {
    $WslUser = (& wsl.exe -d $WslDistro --exec id -un | Select-Object -Last 1).Trim()
    if ($LASTEXITCODE -ne 0 -or $WslUser -notmatch '^[a-z_][a-z0-9_-]*$') {
        throw "Could not resolve the default user for WSL distribution: $WslDistro"
    }
    $LinuxRepo = "/home/$WslUser/multica"
}
if ($LinuxRepo -notmatch '^/[A-Za-z0-9._/-]+$') { throw "Invalid WSL repository path: $LinuxRepo" }
$GatewayUrl = "http://127.0.0.1:$GatewayPort"
$EffectiveOrigin = if ($PublishedUrl) { $PublishedUrl } else { $GatewayUrl }
$CacheEntries = @(
    "TOPOLOGY=windows-wsl", "WSL_DISTRO=$WslDistro", "LINUX_REPO=$LinuxRepo",
    "GATEWAY_PORT=$GatewayPort", "PUBLISHED_URL=$PublishedUrl"
)
& (Join-Path $PSScriptRoot "profile-cache.ps1") set -Profile $Profile -Entry $CacheEntries *> $null
$ExistingStatePath = Join-Path $env:USERPROFILE ".multica\selfhost-server\$Profile\state.json"
if (-not (Test-Path -LiteralPath $ExistingStatePath)) {
    $CachedProfile = (& (Join-Path $PSScriptRoot "profile-cache.ps1") show -Profile $Profile) |
        ConvertFrom-Json
    $Phase = [string]$CachedProfile.values.ONBOARDING_PHASE
    if ($Phase -notin @("tailscale-ready", "server-ready", "owner-registration-required", "cluster-finalizing", "complete")) {
        throw "Tailscale readiness must be completed before initial server startup."
    }
}
& (Join-Path $PSScriptRoot "apply-admission.ps1") -Profile $Profile `
    -WslDistro $WslDistro -LinuxRepo $LinuxRepo
if ($LASTEXITCODE -ne 0) { throw "Could not apply the cached admission policy." }

$LogDirectory = Join-Path $env:LOCALAPPDATA "Multica"
$LogPath = Join-Path $LogDirectory "selfhost-server-$Profile.log"
New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null
function Write-SafeLog([string] $Message) {
    $Line = "[$(Get-Date -Format o)] $Message"
    Add-Content -LiteralPath $LogPath -Value $Line -Encoding utf8
    Write-Output $Line
}

function Get-PublishedPort {
    param([string] $Service, [int] $ContainerPort, [switch] $AllowMissing)
    $Container = (& wsl.exe -d $WslDistro --exec docker compose `
        -f "$LinuxRepo/docker-compose.selfhost.yml" ps -q $Service | Select-Object -Last 1).Trim()
    if ($LASTEXITCODE -ne 0 -or $Container -notmatch '^[a-f0-9]{12,64}$') {
        throw "Could not resolve the container for $Service."
    }
    $Output = & wsl.exe -d $WslDistro --exec docker port $Container "${ContainerPort}/tcp" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $Output) {
        if ($AllowMissing) { return $null }
        throw "Could not resolve the published port for $Service/$ContainerPort."
    }
    foreach ($Binding in @($Output)) {
        if ([string]$Binding -notmatch '^(127\.0\.0\.1|\[::1\]):[0-9]{1,5}\s*$') {
            throw "Unsafe host binding for $Service/${ContainerPort}: $Binding"
        }
    }
    $Match = [regex]::Match([string]($Output | Select-Object -Last 1), ':([0-9]{1,5})\s*$')
    if (-not $Match.Success) {
        if ($AllowMissing) { return $null }
        throw "Unexpected published port for $Service/$ContainerPort."
    }
    $Port = [int]$Match.Groups[1].Value
    if ($Port -lt 1 -or $Port -gt 65535) {
        if ($AllowMissing) { return $null }
        throw "Invalid published port: $Port"
    }
    return $Port
}

function Set-SelfHostOrigin([string] $Origin) {
    $EnvironmentPath = "\\wsl.localhost\$WslDistro$($LinuxRepo.Replace('/', '\'))\.env"
    if (-not (Test-Path -LiteralPath $EnvironmentPath)) {
        throw "Multica environment file not found: $LinuxRepo/.env"
    }
    $Updates = [ordered]@{
        FRONTEND_ORIGIN = $Origin
        MULTICA_APP_URL = $Origin
        CORS_ALLOWED_ORIGINS = $Origin
        COOKIE_DOMAIN = ""
        NEXT_PUBLIC_API_URL = ""
        NEXT_PUBLIC_WS_URL = ""
        APP_ENV = "development"
        MULTICA_DEV_VERIFICATION_CODE = "114514"
    }
    $Lines = [System.Collections.Generic.List[string]]::new()
    foreach ($Line in [System.IO.File]::ReadAllLines($EnvironmentPath)) { $Lines.Add($Line) }
    foreach ($Key in $Updates.Keys) {
        $Replacement = "$Key=$($Updates[$Key])"
        $Found = $false
        for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
            if ($Lines[$Index] -match "^$([regex]::Escape($Key))=") {
                $Lines[$Index] = $Replacement
                $Found = $true
                break
            }
        }
        if (-not $Found) { $Lines.Add($Replacement) }
    }
    $Temporary = "$EnvironmentPath.tmp.$PID"
    [System.IO.File]::WriteAllLines($Temporary, $Lines, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $Temporary -Destination $EnvironmentPath -Force
    & wsl.exe -d $WslDistro --exec chmod 600 "$LinuxRepo/.env"
    if ($LASTEXITCODE -ne 0) { throw "Could not restrict permissions on $LinuxRepo/.env." }
}

function Start-SameOriginGateway {
    $Caddyfile = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\assets\Caddyfile.gateway")).Path
    $CaddyfileWsl = (& wsl.exe -d $WslDistro --exec wslpath -a $Caddyfile | Select-Object -Last 1).Trim()
    if ($LASTEXITCODE -ne 0 -or $CaddyfileWsl -notmatch '^/[A-Za-z0-9._/ -]+$') {
        throw "Could not resolve the Caddy gateway configuration in WSL."
    }
    $BackendContainer = (& wsl.exe -d $WslDistro --exec docker compose `
        -f "$LinuxRepo/docker-compose.selfhost.yml" ps -q backend | Select-Object -Last 1).Trim()
    if ($LASTEXITCODE -ne 0 -or $BackendContainer -notmatch '^[a-f0-9]{12,64}$') {
        throw "Could not resolve the backend container for the gateway."
    }
    $Inspection = ((& wsl.exe -d $WslDistro --exec docker inspect $BackendContainer) -join "`n") | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or -not $Inspection) { throw "Could not inspect the backend network." }
    $Networks = @($Inspection[0].NetworkSettings.Networks.PSObject.Properties.Name)
    if ($Networks.Count -ne 1 -or $Networks[0] -notmatch '^[A-Za-z0-9_.-]+$') {
        throw "Expected exactly one safe Compose network for the backend."
    }
    $NetworkName = $Networks[0]
    $GatewayContainer = "multica-$Profile-gateway"
    & wsl.exe -d $WslDistro --exec docker inspect $GatewayContainer *> $null
    if ($LASTEXITCODE -eq 0) {
        & wsl.exe -d $WslDistro --exec docker rm -f $GatewayContainer *> $null
        if ($LASTEXITCODE -ne 0) { throw "Could not replace the existing gateway container." }
    }
    & wsl.exe -d $WslDistro --exec docker run -d `
        --name $GatewayContainer `
        --restart unless-stopped `
        --network $NetworkName `
        -p "127.0.0.1:${GatewayPort}:${GatewayPort}" `
        -e "MULTICA_GATEWAY_PORT=$GatewayPort" `
        -v "$CaddyfileWsl`:/etc/caddy/Caddyfile:ro" `
        caddy:2-alpine *> $null
    if ($LASTEXITCODE -ne 0) { throw "Could not start the same-origin Caddy gateway." }
}

function Write-StateAndReceipt {
    param([int] $BackendPort, [int] $FrontendPort, [AllowNull()] [Nullable[int]] $DatabaseHostPort)
    $StateDirectory = Join-Path $env:USERPROFILE ".multica\selfhost-server\$Profile"
    New-Item -ItemType Directory -Force -Path $StateDirectory | Out-Null
    $LocalBackendUrl = "http://127.0.0.1:$BackendPort"
    $LocalFrontendUrl = "http://127.0.0.1:$FrontendPort"
    $ConnectionServerUrl = $EffectiveOrigin
    $ConnectionAppUrl = $EffectiveOrigin
    $UpdatedAt = (Get-Date).ToUniversalTime().ToString("o")

    $State = [ordered]@{
        schema_version = 1; profile = $Profile; topology = "wsl-docker-server"
        backend = [ordered]@{ url = $LocalBackendUrl; host_port = $BackendPort; container_port = 8080 }
        frontend = [ordered]@{ url = $LocalFrontendUrl; host_port = $FrontendPort; container_port = 3000 }
        gateway = [ordered]@{ url = $GatewayUrl; host_port = $GatewayPort; container_image = "caddy:2-alpine" }
        database = [ordered]@{
            engine = "postgresql"; container_host = "postgres"; container_port = 5432
            host_published = ($null -ne $DatabaseHostPort); host_port = $DatabaseHostPort
        }
        server_repo = $LinuxRepo; wsl_distro = $WslDistro; published_url = $PublishedUrl
        identity_model = "individual-members"
        admission_policy = "server-env-and-workspace-invite"
        authentication_mode = "fixed-private-code"
        fixed_verification_code = "114514"
        updated_at = $UpdatedAt
    }
    $Receipt = [ordered]@{
        schema_version = 1; profile = $Profile; server_url = $ConnectionServerUrl
        app_url = $ConnectionAppUrl; same_origin = ($ConnectionServerUrl -eq $ConnectionAppUrl)
        access_scope = if ($PublishedUrl) { "published-private" } else { "local-only" }
        identity_model = "individual-members"
        admission_policy = "server-env-and-workspace-invite"
        authentication_mode = "fixed-private-code"
        fixed_verification_code = "114514"
        server_device = $env:COMPUTERNAME; updated_at = $UpdatedAt
    }
    foreach ($Entry in @(
        @{ Path = (Join-Path $StateDirectory "state.json"); Value = $State },
        @{ Path = (Join-Path $StateDirectory "connection.json"); Value = $Receipt }
    )) {
        $Temporary = "$($Entry.Path).tmp.$PID"
        $Entry.Value | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Temporary -Encoding utf8
        Move-Item -LiteralPath $Temporary -Destination $Entry.Path -Force
    }
    return $Receipt
}

Write-SafeLog "Starting Multica self-host server in $WslDistro"
try {
    & wsl.exe -d $WslDistro -u root --exec systemctl start docker.service
    if ($LASTEXITCODE -ne 0) { throw "Could not start Docker in WSL." }
    Set-SelfHostOrigin $EffectiveOrigin
    & wsl.exe -d $WslDistro --exec docker compose `
        -f "$LinuxRepo/docker-compose.selfhost.yml" up -d
    if ($LASTEXITCODE -ne 0) { throw "Could not start the Multica Compose stack." }

    $BackendPort = Get-PublishedPort -Service backend -ContainerPort 8080
    $FrontendPort = Get-PublishedPort -Service frontend -ContainerPort 3000
    $DatabaseHostPort = Get-PublishedPort -Service postgres -ContainerPort 5432 -AllowMissing
    if ($null -ne $DatabaseHostPort) { throw "PostgreSQL must not be published on the host." }
    Start-SameOriginGateway
    $ReadyUrl = "http://127.0.0.1:$BackendPort/readyz"
    $Ready = $false
    for ($Attempt = 0; $Attempt -lt $TimeoutSeconds; $Attempt++) {
        try {
            $Response = Invoke-RestMethod $ReadyUrl -TimeoutSec 2
            if ($Response.status -eq "ok") { $Ready = $true; break }
        } catch {}
        Start-Sleep -Seconds 1
    }
    if (-not $Ready) { throw "Multica backend did not become ready within $TimeoutSeconds seconds." }
    $GatewayReady = $false
    for ($Attempt = 0; $Attempt -lt $TimeoutSeconds; $Attempt++) {
        try {
            $Response = Invoke-WebRequest "$GatewayUrl/api/config" -TimeoutSec 2
            if ($Response.StatusCode -eq 200) { $GatewayReady = $true; break }
        } catch {}
        Start-Sleep -Seconds 1
    }
    if (-not $GatewayReady) { throw "The same-origin gateway did not become ready within $TimeoutSeconds seconds." }

    $Receipt = Write-StateAndReceipt -BackendPort $BackendPort -FrontendPort $FrontendPort `
        -DatabaseHostPort $DatabaseHostPort
    Write-SafeLog "Self-host server is ready; connection receipt updated."
    $Receipt | ConvertTo-Json -Depth 5
} catch {
    Write-SafeLog "Server startup failed: $($_.Exception.Message)"
    throw
}

if ($KeepAlive) {
    Write-SafeLog "Keeping the WSL server distribution alive for the scheduled task."
    & wsl.exe -d $WslDistro --exec sh -c 'while systemctl is-active --quiet docker.service; do sleep 30; done'
    if ($LASTEXITCODE -ne 0) { throw "The WSL server keepalive exited unexpectedly." }
}
