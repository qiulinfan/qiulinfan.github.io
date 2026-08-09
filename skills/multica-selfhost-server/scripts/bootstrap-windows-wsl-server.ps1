<# Install only Docker Engine and the Multica self-host server inside Ubuntu WSL2. #>

[CmdletBinding()]
param(
    [string] $WslDistro = "Ubuntu-26.04",
    [string] $LinuxRepo = "",
    [string] $Profile = "home",
    [string] $PublishedUrl = "",
    [ValidateRange(1, 65535)] [int] $GatewayPort = 8787,
    [switch] $AllowProxyCredentials
)

$ErrorActionPreference = "Stop"
$MulticaGitUrl = "https://github.com/multica-ai/multica.git"

function Invoke-WslBash {
    param([Parameter(Mandatory)] [string] $Script, [switch] $Root)
    $Encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Script))
    $Arguments = @("-d", $WslDistro)
    if ($Root) { $Arguments += @("-u", "root") }
    $Arguments += @("--exec", "bash", "-c", "echo $Encoded | base64 -d | bash")
    & wsl.exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "WSL command failed in '$WslDistro' with exit code $LASTEXITCODE." }
}

if ($WslDistro -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid WSL distribution: $WslDistro" }
if ($Profile -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid Multica profile: $Profile" }
& wsl.exe -d $WslDistro --exec true
if ($LASTEXITCODE -ne 0) { throw "WSL distribution is unavailable: $WslDistro" }
$WslUser = (Invoke-WslBash -Script "set -euo pipefail`nid -un" | Select-Object -Last 1).Trim()
if ($WslUser -notmatch '^[a-z_][a-z0-9_-]*$') { throw "Unsafe WSL user: $WslUser" }
if ([string]::IsNullOrWhiteSpace($LinuxRepo)) { $LinuxRepo = "/home/$WslUser/multica" }
if ($LinuxRepo -notmatch '^/[A-Za-z0-9._/-]+$') { throw "Invalid WSL repository path: $LinuxRepo" }
$CacheEntries = @(
    "TOPOLOGY=windows-wsl", "WSL_DISTRO=$WslDistro", "LINUX_REPO=$LinuxRepo",
    "GATEWAY_PORT=$GatewayPort"
)
if ($PublishedUrl) { $CacheEntries += "PUBLISHED_URL=$PublishedUrl" }
& (Join-Path $PSScriptRoot "profile-cache.ps1") set -Profile $Profile -Entry $CacheEntries *> $null
$CachedProfile = (& (Join-Path $PSScriptRoot "profile-cache.ps1") show -Profile $Profile) | ConvertFrom-Json
$Phase = [string]$CachedProfile.values.ONBOARDING_PHASE
if ($Phase -notin @("tailscale-ready", "server-ready", "owner-registration-required", "cluster-finalizing", "complete")) {
    throw "Tailscale readiness must be completed before server bootstrap. Run the readiness check first."
}

Write-Output "Installing or verifying Docker Engine inside $WslDistro..."
$DockerInstall = @"
set -euo pipefail
if command -v docker >/dev/null 2>&1; then
  systemctl enable --now docker.service containerd.service >/dev/null 2>&1 || true
  docker info >/dev/null 2>&1 || { echo 'Docker exists but its daemon is unusable.' >&2; exit 20; }
  usermod -aG docker $WslUser
  exit 0
fi
. /etc/os-release
[ "`$ID" = ubuntu ] || { echo 'Only Ubuntu WSL is supported.' >&2; exit 21; }
conflicts="`$(dpkg-query -W -f='`${binary:Package}\n' docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc 2>/dev/null || true)"
[ -z "`$conflicts" ] || { echo "Conflicting Docker packages: `$conflicts" >&2; exit 22; }
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: `${UBUNTU_CODENAME:-`$VERSION_CODENAME}
Components: stable
Architectures: `$(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker $WslUser
systemctl enable --now docker.service containerd.service
"@
Invoke-WslBash -Script $DockerInstall -Root

$DockerProbe = "set -euo pipefail`ndocker version >/dev/null`ndocker compose version >/dev/null"
Invoke-WslBash -Script $DockerProbe
$AllowFlag = if ($AllowProxyCredentials) { "true" } else { "false" }
$ProxySetup = @"
set -euo pipefail
proxy="`${HTTPS_PROXY:-`${https_proxy:-}}"
[ -n "`$proxy" ] || { echo 'No HTTPS proxy is available.' >&2; exit 30; }
if [[ "`$proxy" == *'@'* ]] && [ "$AllowFlag" != true ]; then
  echo 'Proxy URL contains credentials; review and rerun with -AllowProxyCredentials.' >&2
  exit 31
fi
install -m 0755 -d /etc/systemd/system/docker.service.d
{
  printf '[Service]\n'
  printf 'Environment="HTTP_PROXY=%s"\n' "`$proxy"
  printf 'Environment="HTTPS_PROXY=%s"\n' "`$proxy"
  printf 'Environment="NO_PROXY=localhost,127.0.0.1,::1"\n'
} > /etc/systemd/system/docker.service.d/http-proxy.conf
chmod 0644 /etc/systemd/system/docker.service.d/http-proxy.conf
systemctl daemon-reload
systemctl restart docker
"@

Write-Output "Cloning or verifying the Multica server repository..."
$ServerSetup = @"
set -euo pipefail
repo=$LinuxRepo
if [ ! -d "`$repo/.git" ]; then
  [ ! -e "`$repo" ] || { echo "Target exists but is not a Git checkout: `$repo" >&2; exit 40; }
  git clone --depth 1 $MulticaGitUrl "`$repo"
fi
test -f "`$repo/docker-compose.selfhost.yml"
origin="`$(git -C "`$repo" remote get-url origin)"
case "`$origin" in
  https://github.com/multica-ai/multica.git|git@github.com:multica-ai/multica.git) ;;
  *) echo "Unexpected Multica origin: `$origin" >&2; exit 41 ;;
esac
if [ ! -f "`$repo/.env" ]; then
  cp "`$repo/.env.example" "`$repo/.env"
  jwt="`$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')"
  sed -i "s/^JWT_SECRET=.*/JWT_SECRET=`$jwt/" "`$repo/.env"
fi
chmod 0600 "`$repo/.env"
"@
Invoke-WslBash -Script $ServerSetup

& (Join-Path $PSScriptRoot "apply-admission.ps1") -Profile $Profile `
    -WslDistro $WslDistro -LinuxRepo $LinuxRepo
if ($LASTEXITCODE -ne 0) { throw "Could not apply the cached admission policy." }
$ComposePull = "set -euo pipefail`ndocker compose -f '$LinuxRepo/docker-compose.selfhost.yml' pull"
try {
    Invoke-WslBash -Script $ComposePull
} catch {
    Invoke-WslBash -Script $ProxySetup -Root
    Invoke-WslBash -Script $ComposePull
}

$Starter = Join-Path $PSScriptRoot "start-windows-wsl-server.ps1"
$StarterArguments = @{
    WslDistro = $WslDistro; LinuxRepo = $LinuxRepo; Profile = $Profile; GatewayPort = $GatewayPort
}
if ($PublishedUrl) { $StarterArguments.PublishedUrl = $PublishedUrl }
& $Starter @StarterArguments
if ($LASTEXITCODE -ne 0) { throw "Self-host server verification failed." }
Write-Output "Multica self-host server is ready. Continue with multica-runtime-client to register this host as the first runtime."
