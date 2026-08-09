#!/bin/sh
# Complete macOS Clash Verge reference path; fail closed for every other VPN/proxy client.

set -eu

server_url=${1:-}
profile=${2:-remote}
public_probe=${3:-${MULTICA_PUBLIC_CONNECTIVITY_PROBE:-https://accounts.google.com/}}
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
clash_helper="$script_dir/configure-clash-verge-routing.rb"

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
  client=${2:-unknown}
  mode=${3:-unknown}
  action=${4:-configure_vpn_split_routing}
  printf '{"schema_version":1,"status":"manual_action_required","phase":"vpn-routing-required","action":"%s","reason":"%s","vpn_client":"%s","vpn_mode":"%s","required_direct":"*.ts.net,100.64.0.0/10,fd7a:115c:a1e0::/48","background_work":false,"resume_hint":"rerun_client_setup"}\n' \
    "$action" "$reason" "$client" "$mode"
  exit 7
}

for required_command in scutil networksetup curl awk grep paste pgrep ruby sed; do
  command -v "$required_command" >/dev/null 2>&1 || {
    echo "$required_command is required." >&2
    exit 3
  }
done
[ -x "$clash_helper" ] || { echo "Clash Verge routing helper is not executable." >&2; exit 3; }

clash_root=${CLASH_VERGE_CONFIG_ROOT:-$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev}
verge_yaml="$clash_root/verge.yaml"
generated_yaml="$clash_root/clash-verge.yaml"
clash_running=false
if pgrep -x clash-verge >/dev/null 2>&1; then
  clash_running=true
else
  pgrep_status=$?
  [ "$pgrep_status" -eq 1 ] || manual process_inspection_unavailable unknown unknown
fi

proxy_state=$(scutil --proxy)
proxy_enabled=false
for enable_key in HTTPEnable HTTPSEnable SOCKSEnable ProxyAutoConfigEnable; do
  if printf '%s\n' "$proxy_state" | grep -Eq "^[[:space:]]*$enable_key[[:space:]]*:[[:space:]]*1$"; then
    proxy_enabled=true
    break
  fi
done

if [ "$clash_running" != true ]; then
  connected_vpn=$(scutil --nc list 2>/dev/null | grep '^\* (Connected)' | grep -vi tailscale || true)
  detected_process=$(pgrep -ifl 'surge|quantumult|shadowrocket|v2ray|xray|sing-box|loon|stash|mihomo|wireguard|openvpn|vpn' | head -n 1 || true)
  if [ "$proxy_enabled" = true ] || [ -n "$connected_vpn" ] || [ -n "$detected_process" ]; then
    manual unsupported_vpn_or_proxy_detected unknown unknown
  fi
  printf '{"schema_version":1,"status":"ready","phase":"vpn-routing-not-required","vpn_client":"none_detected","server_url":"%s"}\n' "$server_url"
  exit 0
fi

[ -f "$verge_yaml" ] || manual clash_verge_config_missing clash-verge unknown
tun_enabled=$(sed -n 's/^[[:space:]]*enable_tun_mode:[[:space:]]*//p' "$verge_yaml" | head -n 1)
system_proxy_enabled=$(sed -n 's/^[[:space:]]*enable_system_proxy:[[:space:]]*//p' "$verge_yaml" | head -n 1)
[ "$tun_enabled" != true ] || manual clash_verge_tun_mode_requires_client_rules clash-verge tun
if [ "$system_proxy_enabled" != true ] && [ "$proxy_enabled" != true ]; then
  printf '{"schema_version":1,"status":"ready","phase":"vpn-routing-not-required","vpn_client":"clash-verge","vpn_mode":"inactive","server_url":"%s"}\n' "$server_url"
  exit 0
fi
[ "$system_proxy_enabled" = true ] || manual clash_verge_mode_does_not_match_system_proxy clash-verge system-proxy

if printf '%s\n' "$proxy_state" | grep -Eq '^[[:space:]]*HTTPSEnable[[:space:]]*:[[:space:]]*1$'; then
  proxy_host=$(printf '%s\n' "$proxy_state" | sed -n 's/^[[:space:]]*HTTPSProxy[[:space:]]*:[[:space:]]*//p' | head -n 1)
  proxy_port=$(printf '%s\n' "$proxy_state" | sed -n 's/^[[:space:]]*HTTPSPort[[:space:]]*:[[:space:]]*//p' | head -n 1)
  proxy_url="http://$proxy_host:$proxy_port"
  networksetup_get=-getsecurewebproxy
elif printf '%s\n' "$proxy_state" | grep -Eq '^[[:space:]]*HTTPEnable[[:space:]]*:[[:space:]]*1$'; then
  proxy_host=$(printf '%s\n' "$proxy_state" | sed -n 's/^[[:space:]]*HTTPProxy[[:space:]]*:[[:space:]]*//p' | head -n 1)
  proxy_port=$(printf '%s\n' "$proxy_state" | sed -n 's/^[[:space:]]*HTTPPort[[:space:]]*:[[:space:]]*//p' | head -n 1)
  proxy_url="http://$proxy_host:$proxy_port"
  networksetup_get=-getwebproxy
elif printf '%s\n' "$proxy_state" | grep -Eq '^[[:space:]]*SOCKSEnable[[:space:]]*:[[:space:]]*1$'; then
  proxy_host=$(printf '%s\n' "$proxy_state" | sed -n 's/^[[:space:]]*SOCKSProxy[[:space:]]*:[[:space:]]*//p' | head -n 1)
  proxy_port=$(printf '%s\n' "$proxy_state" | sed -n 's/^[[:space:]]*SOCKSPort[[:space:]]*:[[:space:]]*//p' | head -n 1)
  proxy_url="socks5h://$proxy_host:$proxy_port"
  networksetup_get=-getsocksfirewallproxy
else
  manual clash_verge_proxy_endpoint_missing clash-verge system-proxy
fi
case "$proxy_host" in ''|*'/'*|*'@'*|*[[:space:]]*) manual invalid_system_proxy_host clash-verge system-proxy ;; esac
case "$proxy_port" in ''|*[!0-9]*) manual invalid_system_proxy_port clash-verge system-proxy ;; esac

helper_status=0
"$clash_helper" check "$clash_root" >/dev/null 2>&1 || helper_status=$?
case "$helper_status" in
  0) config_changed=false ;;
  10)
    "$clash_helper" apply "$clash_root" >/dev/null 2>&1 || manual clash_verge_rules_config_failed clash-verge system-proxy
    config_changed=true
    ;;
  *) manual clash_verge_config_not_safely_editable clash-verge system-proxy ;;
esac

# Apply an immediate OS bypass without treating it as the persistence layer.
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
    current_bypass=$(networksetup -getproxybypassdomains "$service" 2>/dev/null | grep -v "There aren't any bypass domains set" || true)
    merged_lines=$(printf '%s\n%s\n%s\n%s\n' "$current_bypass" '*.ts.net' '100.64.0.0/10' 'fd7a:115c:a1e0::/48' | awk 'NF && !seen[$0]++')
    IFS='
'
    set -- $merged_lines
    IFS=$old_ifs
    networksetup -setproxybypassdomains "$service" "$@" >/dev/null 2>&1 || manual system_proxy_bypass_update_failed clash-verge system-proxy
    matched_services=$((matched_services + 1))
  fi
done
IFS=$old_ifs
[ "$matched_services" -gt 0 ] || manual matching_network_service_not_found clash-verge system-proxy

if [ "$config_changed" = true ]; then
  manual clash_verge_profile_reload_required clash-verge system-proxy restart_clash_verge
fi

for required_rule in \
  'DOMAIN-SUFFIX,ts.net,DIRECT' \
  'IP-CIDR,100.64.0.0/10,DIRECT,no-resolve' \
  'IP-CIDR6,fd7a:115c:a1e0::/48,DIRECT,no-resolve'; do
  grep -Fq "$required_rule" "$generated_yaml" || manual clash_verge_profile_reload_required clash-verge system-proxy restart_clash_verge
done

curl -fsS --noproxy '*' --connect-timeout 5 --max-time 15 "$server_url/api/config" >/dev/null 2>&1 || \
  manual multica_direct_path_failed clash-verge system-proxy
curl -fsS --noproxy '' -x "$proxy_url" --connect-timeout 5 --max-time 15 "$server_url/api/config" >/dev/null 2>&1 || \
  manual multica_proxy_fallback_rule_failed clash-verge system-proxy
curl -fsS --noproxy '' -x "$proxy_url" --connect-timeout 5 --max-time 20 "$public_probe" >/dev/null 2>&1 || \
  manual public_proxy_path_failed clash-verge system-proxy

printf '{"schema_version":1,"status":"ready","phase":"vpn-routing-ready","vpn_client":"clash-verge","vpn_mode":"system-proxy","persistence":"rules-enhancement","server_url":"%s","public_probe":"%s","direct_rules":"DOMAIN-SUFFIX:ts.net,IP-CIDR:100.64.0.0/10,IP-CIDR6:fd7a:115c:a1e0::/48"}\n' \
  "$server_url" "$public_probe"
