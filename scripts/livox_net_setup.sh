#!/bin/bash
# Host-side network setup for the Livox Mid-360(S). Run on the HOST, ONCE per
# machine (root). It is now PERSISTENT — you do NOT run it after every reboot:
#
#   sudo bash scripts/livox_net_setup.sh [IFACE] [HOST_IP]
#
# Why this is needed
#   The Mid-360 streams over Ethernet on 192.168.1.0/24 to a fixed host IP. On
#   a multi-homed machine (one NIC to the internet, one to the lidar) two
#   things break by default:
#     1. The lidar NIC has no IP on the lidar subnet.
#     2. Livox uses limited broadcast 255.255.255.255, which the kernel sends
#        out the DEFAULT-ROUTE NIC (the internet one), not the lidar NIC.
#   BOTH fixes are now baked into a persistent NetworkManager profile, so
#   NetworkManager re-applies them automatically on every boot / cable
#   re-plug. No per-reboot script, no NM dispatcher hook needed.
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
