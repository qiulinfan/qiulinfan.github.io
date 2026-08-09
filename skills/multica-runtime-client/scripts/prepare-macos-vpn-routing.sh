#!/bin/sh
# Keep private Tailscale Multica traffic direct while a macOS internet proxy remains usable.

set -eu

server_url=${1:-}
profile=${2:-remote}
public_probe=${3:-${MULTICA_PUBLIC_CONNECTIVITY_PROBE:-https://accounts.google.com/}}

[ "$(uname -s)" = Darwin ] || { echo "This check is only for macOS." >&2; exit 3; }
case "$server_url" in https://*) ;; *) echo "Server URL must be a Tailscale HTTPS origin." >&2; exit 2 ;; esac
server_url=${server_url%/}
server_host=${server_url#https://}
case "$server_host" in *'/'*|*':'*|*'@'*|*[?#]*|'') echo "Server URL must be a credential-free HTTPS origin on port 443." >&2; exit 2 ;; esac
case "$server_host" in *.ts.net) ;; *) echo "Server URL host must end in .ts.net." >&2; exit 2 ;; esac
case "$profile" in ''|*[!A-Za-z0-9._-]*) echo "Invalid profile: $profile" >&2; exit 2 ;; esac
case "$public_probe" in https://*) ;; *) echo "Public connectivity probe must use HTTPS." >&2; exit 2 ;; esac
case "$public_probe" in *'@'*|*'"'*|*"'"*|*[[:space:]]*) echo "Public connectivity probe must be credential-free." >&2; exit 2 ;; esac

manual() {
  reason=$1
  printf '{"schema_version":1,"status":"manual_action_required","phase":"vpn-routing-required","action":"configure_vpn_split_routing","reason":"%s","background_work":false,"resume_hint":"rerun_runtime_client"}\n' "$reason"
  exit 7
}

for required_command in scutil networksetup curl awk sed grep paste pgrep stat; do
  command -v "$required_command" >/dev/null 2>&1 || {
    echo "$required_command is required." >&2
    exit 3
  }
done

clash_root=${CLASH_VERGE_CONFIG_ROOT:-$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev}
verge_yaml="$clash_root/verge.yaml"
clash_running=false
if pgrep -ifl 'clash-verge|verge-mihomo' >/dev/null 2>&1; then clash_running=true; fi

proxy_state=$(scutil --proxy)
proxy_enabled=false
for enable_key in HTTPEnable HTTPSEnable SOCKSEnable ProxyAutoConfigEnable; do
  if printf '%s\n' "$proxy_state" | grep -Eq "^[[:space:]]*$enable_key[[:space:]]*:[[:space:]]*1$"; then
    proxy_enabled=true
    break
  fi
done

if [ "$clash_running" = true ]; then
  [ -f "$verge_yaml" ] || manual clash_verge_config_missing
  tun_enabled=$(sed -n 's/^[[:space:]]*enable_tun_mode:[[:space:]]*//p' "$verge_yaml" | head -n 1)
  system_proxy_enabled=$(sed -n 's/^[[:space:]]*enable_system_proxy:[[:space:]]*//p' "$verge_yaml" | head -n 1)
  [ "$tun_enabled" != true ] || manual clash_verge_tun_mode_requires_explicit_exclusions
  if [ "$system_proxy_enabled" != true ] && [ "$proxy_enabled" != true ]; then
    printf '{"schema_version":1,"status":"ready","phase":"vpn-routing-not-required","vpn_client":"clash-verge","vpn_mode":"inactive","server_url":"%s"}\n' "$server_url"
    exit 0
  fi
  [ "$system_proxy_enabled" = true ] || manual clash_verge_mode_does_not_match_system_proxy
else
  connected_vpn=$(scutil --nc list 2>/dev/null | grep '^\* (Connected)' | grep -vi 'tailscale' || true)
  if [ "$proxy_enabled" = true ] || [ -n "$connected_vpn" ] || \
     pgrep -ifl 'surge|quantumult|shadowrocket|v2ray|xray|sing-box|loon|stash|mihomo|wireguard|openvpn' >/dev/null 2>&1; then
    manual unsupported_vpn_or_proxy_detected
  fi
  printf '{"schema_version":1,"status":"ready","phase":"vpn-routing-not-required","vpn_client":"none_detected","server_url":"%s"}\n' "$server_url"
  exit 0
fi

[ "$proxy_enabled" = true ] || manual clash_verge_system_proxy_not_active
if printf '%s\n' "$proxy_state" | grep -Eq '^[[:space:]]*HTTPSEnable[[:space:]]*:[[:space:]]*1$'; then
  proxy_type=https
  proxy_host=$(printf '%s\n' "$proxy_state" | sed -n 's/^[[:space:]]*HTTPSProxy[[:space:]]*:[[:space:]]*//p' | head -n 1)
  proxy_port=$(printf '%s\n' "$proxy_state" | sed -n 's/^[[:space:]]*HTTPSPort[[:space:]]*:[[:space:]]*//p' | head -n 1)
  networksetup_get=-getsecurewebproxy
elif printf '%s\n' "$proxy_state" | grep -Eq '^[[:space:]]*HTTPEnable[[:space:]]*:[[:space:]]*1$'; then
  proxy_type=http
  proxy_host=$(printf '%s\n' "$proxy_state" | sed -n 's/^[[:space:]]*HTTPProxy[[:space:]]*:[[:space:]]*//p' | head -n 1)
  proxy_port=$(printf '%s\n' "$proxy_state" | sed -n 's/^[[:space:]]*HTTPPort[[:space:]]*:[[:space:]]*//p' | head -n 1)
  networksetup_get=-getwebproxy
elif printf '%s\n' "$proxy_state" | grep -Eq '^[[:space:]]*SOCKSEnable[[:space:]]*:[[:space:]]*1$'; then
  proxy_type=socks
  proxy_host=$(printf '%s\n' "$proxy_state" | sed -n 's/^[[:space:]]*SOCKSProxy[[:space:]]*:[[:space:]]*//p' | head -n 1)
  proxy_port=$(printf '%s\n' "$proxy_state" | sed -n 's/^[[:space:]]*SOCKSPort[[:space:]]*:[[:space:]]*//p' | head -n 1)
  networksetup_get=-getsocksfirewallproxy
else
  manual proxy_auto_config_requires_explicit_split_routing
fi
case "$proxy_host" in ''|*'/'*|*'@'*|*[[:space:]]*) manual invalid_system_proxy_host ;; esac
case "$proxy_port" in ''|*[!0-9]*) manual invalid_system_proxy_port ;; esac

bypass_line_count=$(grep -Ec '^[[:space:]]*system_proxy_bypass:' "$verge_yaml" || true)
[ "$bypass_line_count" -eq 1 ] || manual ambiguous_clash_verge_bypass_config
custom_bypass=$(sed -n 's/^[[:space:]]*system_proxy_bypass:[[:space:]]*//p' "$verge_yaml" | head -n 1)
case "$custom_bypass" in
  null|'') custom_bypass= ;;
  \'*) custom_bypass=${custom_bypass#\'}; custom_bypass=${custom_bypass%\'} ;;
  \"*) custom_bypass=$(printf '%s\n' "$custom_bypass" | sed 's/^"//; s/"$//') ;;
esac
normalized_bypass=$(printf '%s\n' "$custom_bypass" | tr ',' '\n' | awk '{$1=$1} NF && !seen[$0]++' | paste -sd, -)
for required_bypass in '*.ts.net' '100.64.0.0/10' 'fd7a:115c:a1e0::/48'; do
  if ! printf ',%s,' "$normalized_bypass" | grep -Fq ",$required_bypass,"; then
    if [ -n "$normalized_bypass" ]; then normalized_bypass="$normalized_bypass,$required_bypass"
    else normalized_bypass=$required_bypass; fi
  fi
done

config_tmp="$verge_yaml.tmp.$$"
trap 'rm -f "$config_tmp"' EXIT HUP INT TERM
awk -v replacement="system_proxy_bypass: '$normalized_bypass'" '
  /^[[:space:]]*system_proxy_bypass:/ { print replacement; next }
  { print }
' "$verge_yaml" >"$config_tmp"
chmod "$(stat -f %Lp "$verge_yaml")" "$config_tmp"
mv -f "$config_tmp" "$verge_yaml"
trap - EXIT HUP INT TERM

services=$(networksetup -listallnetworkservices 2>/dev/null | sed '1d; /^\*/d')
matched_services=0
old_ifs=$IFS
IFS='
'
for service in $services; do
  proxy_config=$(networksetup "$networksetup_get" "$service" 2>/dev/null || true)
  enabled=$(printf '%s\n' "$proxy_config" | sed -n 's/^Enabled:[[:space:]]*//p' | head -n 1)
  service_host=$(printf '%s\n' "$proxy_config" | sed -n 's/^Server:[[:space:]]*//p' | head -n 1)
  service_port=$(printf '%s\n' "$proxy_config" | sed -n 's/^Port:[[:space:]]*//p' | head -n 1)
  if [ "$enabled" = Yes ] && [ "$service_host" = "$proxy_host" ] && [ "$service_port" = "$proxy_port" ]; then
    current_bypass=$(networksetup -getproxybypassdomains "$service" 2>/dev/null | \
      grep -v "There aren't any bypass domains set" || true)
    merged_lines=$(printf '%s\n%s\n%s\n%s\n' "$current_bypass" '*.ts.net' '100.64.0.0/10' 'fd7a:115c:a1e0::/48' | \
      awk 'NF && !seen[$0]++')
    IFS='
'
    set -- $merged_lines
    IFS=$old_ifs
    networksetup -setproxybypassdomains "$service" "$@" >/dev/null 2>&1 || manual system_proxy_bypass_update_failed
    matched_services=$((matched_services + 1))
  fi
done
IFS=$old_ifs
[ "$matched_services" -gt 0 ] || manual matching_network_service_not_found

active_proxy=$(scutil --proxy)
printf '%s\n' "$active_proxy" | grep -Fq '*.ts.net' || manual active_system_proxy_bypass_not_applied
curl -fsS --noproxy '*' --connect-timeout 5 --max-time 15 "$server_url/api/config" >/dev/null 2>&1 || manual multica_direct_path_failed
if [ "$proxy_type" = socks ]; then proxy_url="socks5h://$proxy_host:$proxy_port"
else proxy_url="http://$proxy_host:$proxy_port"; fi
curl -fsS --noproxy '' -x "$proxy_url" --connect-timeout 5 --max-time 20 "$public_probe" >/dev/null 2>&1 || manual public_proxy_path_failed

printf '{"schema_version":1,"status":"ready","phase":"vpn-routing-ready","vpn_client":"clash-verge","vpn_mode":"system-proxy","server_url":"%s","public_probe":"%s","bypass":"*.ts.net,100.64.0.0/10,fd7a:115c:a1e0::/48"}\n' \
  "$server_url" "$public_probe"
