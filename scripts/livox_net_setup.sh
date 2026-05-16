#!/bin/bash
# Host-side network setup for the Livox Mid-360(S). Run on the HOST (not in a
# container) with root, once per machine and after every reboot:
#
#   sudo bash scripts/livox_net_setup.sh [IFACE] [HOST_IP]
#
# Why this is needed
#   The Mid-360 streams over Ethernet on 192.168.1.0/24 and ships configured to
#   send point/IMU data to a fixed host IP. On a MULTI-HOMED machine (one NIC to
#   the internet, one to the lidar) two things break by default:
#     1. The NIC has no IP on the lidar subnet.
#     2. Livox discovery uses limited broadcast 255.255.255.255, which the
#        kernel sends out the DEFAULT-ROUTE NIC (the internet one), not the
#        lidar NIC, so the lidar never gets discovered.
#   This script fixes both, idempotently. (1) is persistent via NetworkManager;
#   (2) is a runtime route that does NOT survive reboot — hence "run after
#   every reboot", or install the NM dispatcher hook (see README).
set -euo pipefail

IFACE="${1:-enp4s0}"          # lidar-facing NIC
HOST_IP="${2:-192.168.1.5}"   # must match host_net_info in config/MID360_config.json
CON="livox-mid360"

if [[ $EUID -ne 0 ]]; then echo "Run as root (sudo)." >&2; exit 1; fi

echo ">> Static IP ${HOST_IP}/24 on ${IFACE} (NM profile '${CON}', persistent)"
if ! nmcli -t -f NAME con show | grep -qx "${CON}"; then
  nmcli con add type ethernet con-name "${CON}" ifname "${IFACE}" \
        ipv4.method manual ipv4.addresses "${HOST_IP}/24" \
        ipv4.gateway "" ipv4.never-default yes ipv6.method ignore
else
  nmcli con mod "${CON}" connection.interface-name "${IFACE}" \
        ipv4.method manual ipv4.addresses "${HOST_IP}/24" \
        ipv4.gateway "" ipv4.never-default yes
fi
nmcli con up "${CON}"

echo ">> Pin limited broadcast 255.255.255.255 to ${IFACE} (runtime, not reboot-safe)"
ip route replace 255.255.255.255/32 dev "${IFACE}"

echo ">> Done."
ip -brief addr show "${IFACE}"
ip route get 255.255.255.255 | head -1
