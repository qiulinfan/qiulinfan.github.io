<# Native-Windows Docker Desktop controller for only the Multica server stack. #>

[CmdletBinding()]
param(
    [Parameter(Position = 0)] [ValidateSet("up", "down", "status", "logs", "help")] [string] $Command = "help",
    [Parameter(Position = 1)] [string] $Service = "backend",
    [string] $MulticaRepo = $env:MULTICA_REPO,
    [string] $Profile = "home",
    [string] $PublishedUrl = "",
    [ValidateRange(1, 65535)] [int] $GatewayPort = 8787,
    [ValidateRange(10, 600)] [int] $TimeoutSeconds = 120,
    [ValidateRange(1, 5000)] [int] $Lines = 200,
    [switch] $Follow,
    [switch] $Wipe
)

$ErrorActionPreference = "Stop"
$ComposeFile = "docker-compose.selfhost.yml"
if ($Command -ne "help") {
    if ([string]::IsNullOrWhiteSpace($MulticaRepo)) { throw "Specify -MulticaRepo." }
    $MulticaRepo = (Resolve-Path -LiteralPath $MulticaRepo).Path
    if (-not (Test-Path -LiteralPath (Join-Path $MulticaRepo $ComposeFile))) {
        throw "Not a Multica server checkout: $MulticaRepo"
    }
}
if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid profile: $Profile" }
if ($PublishedUrl) {
    $ParsedUrl = $null
    if (-not [Uri]::TryCreate($PublishedUrl, [UriKind]::Absolute, [ref]$ParsedUrl) -or
        $ParsedUrl.Scheme -notin @("http", "https") -or $ParsedUrl.UserInfo) {
        throw "PublishedUrl must be an absolute http(s) URL without credentials."
    }
    $PublishedUrl = $PublishedUrl.TrimEnd('/')
}
$GatewayUrl = "http://127.0.0.1:$GatewayPort"
$EffectiveOrigin = if ($PublishedUrl) { $PublishedUrl } else { $GatewayUrl }
$GatewayContainer = "multica-$Profile-gateway"
if ($Command -ne "help") {
    & (Join-Path $PSScriptRoot "profile-cache.ps1") set -Profile $Profile -Entry @(
        "TOPOLOGY=windows-native", "SERVER_REPO=$MulticaRepo", "GATEWAY_PORT=$GatewayPort",
        "PUBLISHED_URL=$PublishedUrl"
    ) *> $null
}

function Invoke-Compose([string[]] $Arguments) {
    Push-Location $MulticaRepo
    try { & docker compose -f $ComposeFile @Arguments }
    finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { throw "docker compose failed: $($Arguments -join ' ')" }
}

function Get-Port([string] $Name, [int] $ContainerPort, [switch] $AllowMissing) {
    Push-Location $MulticaRepo
    try { $Container = (& docker compose -f $ComposeFile ps -q $Name | Select-Object -Last 1).Trim() }
    finally { Pop-Location }
    if ($LASTEXITCODE -ne 0 -or $Container -notmatch '^[a-f0-9]{12,64}$') {
        throw "Could not resolve the container for $Name."
    }
    $Output = & docker port $Container "${ContainerPort}/tcp" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $Output) {
        if ($AllowMissing) { return $null }
        throw "Could not resolve $Name/$ContainerPort."
    }
    foreach ($Binding in @($Output)) {
        if ([string]$Binding -notmatch '^(127\.0\.0\.1|\[::1\]):[0-9]{1,5}\s*$') {
            throw "Unsafe host binding for $Name/${ContainerPort}: $Binding"
        }
    }
    $Match = [regex]::Match([string]($Output | Select-Object -Last 1), ':([0-9]{1,5})\s*$')
    if (-not $Match.Success) {
        if ($AllowMissing) { return $null }
        throw "Unexpected published port for $Name/$ContainerPort."
    }
    $Port = [int]$Match.Groups[1].Value
    if ($Port -lt 1 -or $Port -gt 65535) {
        if ($AllowMissing) { return $null }
        throw "Invalid published port for $Name/$ContainerPort."
    }
    return $Port
}

function Set-SelfHostOrigin([string] $Origin) {
    $EnvironmentPath = Join-Path $MulticaRepo ".env"
    if (-not (Test-Path -LiteralPath $EnvironmentPath)) { throw "Missing Multica .env file." }
    $Updates = [ordered]@{
        FRONTEND_ORIGIN = $Origin; MULTICA_APP_URL = $Origin; CORS_ALLOWED_ORIGINS = $Origin
        COOKIE_DOMAIN = ""; NEXT_PUBLIC_API_URL = ""; NEXT_PUBLIC_WS_URL = ""
        APP_ENV = "development"; MULTICA_DEV_VERIFICATION_CODE = "114514"
    }
    $Lines = [System.Collections.Generic.List[string]]::new()
    foreach ($Line in [System.IO.File]::ReadAllLines($EnvironmentPath)) { $Lines.Add($Line) }
    foreach ($Key in $Updates.Keys) {
        $Found = $false
        for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
            if ($Lines[$Index] -match "^$([regex]::Escape($Key))=") {
                $Lines[$Index] = "$Key=$($Updates[$Key])"; $Found = $true; break
            }
        }
        if (-not $Found) { $Lines.Add("$Key=$($Updates[$Key])") }
    }
    $Temporary = "$EnvironmentPath.tmp.$PID"
    [System.IO.File]::WriteAllLines($Temporary, $Lines, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $Temporary -Destination $EnvironmentPath -Force
}

function Start-SameOriginGateway {
    Push-Location $MulticaRepo
    try { $BackendContainer = (& docker compose -f $ComposeFile ps -q backend | Select-Object -Last 1).Trim() }
    finally { Pop-Location }
    if ($LASTEXITCODE -ne 0 -or $BackendContainer -notmatch '^[a-f0-9]{12,64}$') {
        throw "Could not resolve the backend container."
    }
    $Inspection = ((& docker inspect $BackendContainer) -join "`n") | ConvertFrom-Json
    $Networks = @($Inspection[0].NetworkSettings.Networks.PSObject.Properties.Name)
    if ($Networks.Count -ne 1 -or $Networks[0] -notmatch '^[A-Za-z0-9_.-]+$') {
        throw "Expected exactly one safe backend network."
    }
    $NetworkName = $Networks[0]
    & docker inspect $GatewayContainer *> $null
    if ($LASTEXITCODE -eq 0) { & docker rm -f $GatewayContainer *> $null }
    $Caddyfile = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\assets\Caddyfile.gateway")).Path
    & docker run -d --name $GatewayContainer --restart unless-stopped `
        --network $NetworkName -p "127.0.0.1:${GatewayPort}:${GatewayPort}" `
        -e "MULTICA_GATEWAY_PORT=$GatewayPort" `
        -v "${Caddyfile}:/etc/caddy/Caddyfile:ro" caddy:2-alpine *> $null
    if ($LASTEXITCODE -ne 0) { throw "Could not start the same-origin gateway." }
}

function Write-State([int] $BackendPort, [int] $FrontendPort, [Nullable[int]] $DatabasePort) {
    $Directory = Join-Path $env:USERPROFILE ".multica\selfhost-server\$Profile"
    New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    $BackendUrl = "http://127.0.0.1:$BackendPort"
    $FrontendUrl = "http://127.0.0.1:$FrontendPort"
    $ConnectionServerUrl = $EffectiveOrigin
    $ConnectionAppUrl = $EffectiveOrigin
    $Now = (Get-Date).ToUniversalTime().ToString("o")
    $State = [ordered]@{
        schema_version = 1; profile = $Profile; topology = "windows-docker-server"
        backend = [ordered]@{ url = $BackendUrl; host_port = $BackendPort; container_port = 8080 }
        frontend = [ordered]@{ url = $FrontendUrl; host_port = $FrontendPort; container_port = 3000 }
        gateway = [ordered]@{ url = $GatewayUrl; host_port = $GatewayPort; container_image = "caddy:2-alpine" }
        database = [ordered]@{ engine = "postgresql"; container_host = "postgres"; container_port = 5432; host_published = ($null -ne $DatabasePort); host_port = $DatabasePort }
        server_repo = $MulticaRepo; published_url = $PublishedUrl
        identity_model = "individual-members"
        admission_policy = "server-env-and-workspace-invite"
        authentication_mode = "fixed-private-code"
        fixed_verification_code = "114514"
        updated_at = $Now
    }
    $Receipt = [ordered]@{
        schema_version = 1; profile = $Profile; server_url = $ConnectionServerUrl
        app_url = $ConnectionAppUrl; same_origin = ($ConnectionServerUrl -eq $ConnectionAppUrl)
        access_scope = if ($PublishedUrl) { "published-private" } else { "local-only" }
        identity_model = "individual-members"
        admission_policy = "server-env-and-workspace-invite"
        authentication_mode = "fixed-private-code"
        fixed_verification_code = "114514"
        server_device = $env:COMPUTERNAME; updated_at = $Now
    }
    foreach ($Entry in @(
        @{ Path = (Join-Path $Directory "state.json"); Value = $State },
        @{ Path = (Join-Path $Directory "connection.json"); Value = $Receipt }
    )) {
        $Temporary = "$($Entry.Path).tmp.$PID"
        $Entry.Value | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Temporary -Encoding utf8
        Move-Item -LiteralPath $Temporary -Destination $Entry.Path -Force
    }
    $Receipt | ConvertTo-Json -Depth 5
}

switch ($Command) {
    "up" {
        $ExistingState = Join-Path $env:USERPROFILE ".multica\selfhost-server\$Profile\state.json"
        if (-not (Test-Path -LiteralPath $ExistingState)) {
            $CachedProfile = (& (Join-Path $PSScriptRoot "profile-cache.ps1") show -Profile $Profile) | ConvertFrom-Json
            $Phase = [string]$CachedProfile.values.ONBOARDING_PHASE
            if ($Phase -notin @("tailscale-ready", "server-ready", "owner-registration-required", "cluster-finalizing", "complete")) {
                throw "Tailscale readiness must be completed before initial server startup."
            }
        }
        docker info *> $null
        if ($LASTEXITCODE -ne 0) { throw "Docker engine is not running." }
        & (Join-Path $PSScriptRoot "apply-admission.ps1") -Profile $Profile `
            -ServerRepo $MulticaRepo
        if ($LASTEXITCODE -ne 0) { throw "Could not apply the cached admission policy." }
        Set-SelfHostOrigin $EffectiveOrigin
        Invoke-Compose @("up", "-d")
        $BackendPort = Get-Port "backend" 8080
        $FrontendPort = Get-Port "frontend" 3000
        $DatabasePort = Get-Port "postgres" 5432 -AllowMissing
        if ($null -ne $DatabasePort) { throw "PostgreSQL must not be published on the host." }
        Start-SameOriginGateway
        $Ready = $false
        for ($Attempt = 0; $Attempt -lt $TimeoutSeconds; $Attempt++) {
            try {
                if ((Invoke-RestMethod "http://127.0.0.1:$BackendPort/readyz" -TimeoutSec 2).status -eq "ok") { $Ready = $true; break }
            } catch {}
            Start-Sleep -Seconds 1
        }
        if (-not $Ready) { throw "Backend did not become ready." }
        $GatewayReady = $false
        for ($Attempt = 0; $Attempt -lt $TimeoutSeconds; $Attempt++) {
            try {
                if ((Invoke-WebRequest "$GatewayUrl/api/config" -TimeoutSec 2).StatusCode -eq 200) {
                    $GatewayReady = $true; break
                }
            } catch {}
            Start-Sleep -Seconds 1
        }
        if (-not $GatewayReady) { throw "Gateway did not become ready." }
        Write-State $BackendPort $FrontendPort $DatabasePort
    }
    "down" {
        & docker inspect $GatewayContainer *> $null
        if ($LASTEXITCODE -eq 0) { & docker rm -f $GatewayContainer *> $null }
        if ($Wipe) {
            if ((Read-Host "Type YES to delete Multica Docker volumes") -ne "YES") { throw "Volume deletion cancelled." }
            Invoke-Compose @("down", "-v")
        } else { Invoke-Compose @("down") }
    }
    "status" {
        Invoke-Compose @("ps")
        & docker ps -a --filter "name=^/$GatewayContainer$" --format "{{.Names}} {{.Status}} {{.Ports}}"
    }
    "logs" {
        if ($Service -eq "gateway") {
            $Arguments = @("logs", "--tail", "$Lines")
            if ($Follow) { $Arguments += "-f" }
            & docker @Arguments $GatewayContainer
            if ($LASTEXITCODE -ne 0) { throw "Could not read gateway logs." }
            break
        }
        if ($Service -notin @("backend", "frontend", "postgres")) { throw "Unknown service: $Service" }
        $Arguments = @("logs", "--tail", "$Lines")
        if ($Follow) { $Arguments += "-f" }
        $Arguments += $Service
        Invoke-Compose $Arguments
    }
    default {
        Write-Output "server.ps1 up|down|status|logs [backend|frontend|postgres] -MulticaRepo <path> [-Profile home]"
    }
}
