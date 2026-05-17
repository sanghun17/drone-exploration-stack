#!/bin/bash
# OPTIONAL bare-metal helper — NOT part of the normal Docker workflow.
#
# In the Docker workflow you do NOT run this: the dev container is privileged +
# network_mode host, so docker/ros_entrypoint.sh puts HOST_IP on the lidar NIC
# itself on every start (no sudo, no host script, portable). And diagnostics
# proved the 255.255.255.255 broadcast route is irrelevant to the unicast
# Mid-360 config (KNOWN_ISSUES.md #1) — only the static IP matters.
#
# Use this ONLY if you run the lidar bare-metal (no container) and want a
# persistent NetworkManager profile instead:
#
#   sudo bash scripts/livox_net_setup.sh [IFACE] [HOST_IP]
#
# It writes one persistent NM profile (static IP + broadcast route),
# auto-detecting the lidar NIC; survives reboots, no per-reboot re-run.
#
# IFACE auto-detects (lidar-subnet NIC -> livox profile NIC -> non-default
# wired NIC -> enp4s0). Override with arg 1. HOST_IP must match
# host_net_info in config/MID360_config.json (default 192.168.1.5).
set -euo pipefail

CON="livox-mid360"
HOST_IP="${2:-192.168.1.5}"

detect_iface() {
  [[ -n "${1:-}" ]] && { echo "$1"; return; }                                  # explicit arg
  local i
  i=$(ip -o -4 addr show 2>/dev/null | awk '/ 192\.168\.1\./{print $2; exit}') # already on lidar subnet
  [[ -n "$i" ]] && { echo "$i"; return; }
  i=$(nmcli -g connection.interface-name con show "$CON" 2>/dev/null || true)   # bound to livox profile
  [[ -n "$i" && "$i" != "--" ]] && { echo "$i"; return; }
  local defif; defif=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
  i=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' \
        | grep -E '^(en|eth)' | grep -vx "${defif:-}" | head -1)               # non-default wired NIC
  [[ -n "$i" ]] && { echo "$i"; return; }
  echo enp4s0                                                                  # fallback
}

if [[ $EUID -ne 0 ]]; then echo "Run as root (sudo)." >&2; exit 1; fi
IFACE="$(detect_iface "${1:-}")"
echo ">> Lidar NIC: ${IFACE}  |  host IP: ${HOST_IP}/24  |  NM profile: ${CON}"

# One persistent NM profile carries BOTH the static IP and the limited-
# broadcast on-link route. NetworkManager re-applies the whole thing on every
# activation (boot, re-plug) -> nothing to re-run by hand.
COMMON=( ipv4.method manual ipv4.addresses "${HOST_IP}/24"
         ipv4.gateway "" ipv4.never-default yes
         ipv4.routes "255.255.255.255/32" ipv6.method ignore )
if ! nmcli -t -f NAME con show | grep -qx "${CON}"; then
  nmcli con add type ethernet con-name "${CON}" ifname "${IFACE}" "${COMMON[@]}"
else
  nmcli con mod "${CON}" connection.interface-name "${IFACE}" "${COMMON[@]}"
fi
nmcli con up "${CON}"

# Apply the broadcast route immediately too (so this session works now without
# waiting for a full reconnect). NM owns the persistent copy.
ip route replace 255.255.255.255/32 dev "${IFACE}"

echo ">> Done — persistent. This survives reboots; no need to re-run."
ip -brief addr show "${IFACE}"
ip route get 255.255.255.255 | head -1
