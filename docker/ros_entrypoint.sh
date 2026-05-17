#!/bin/bash
set -e
source /opt/ros/noetic/setup.bash
# catkin workspace is bind-mounted at /work/ros_ws and built in-container.
if [ -f /work/ros_ws/devel/setup.bash ]; then
  source /work/ros_ws/devel/setup.bash
fi
export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}

# --- Lidar-facing NIC -------------------------------------------------------
# Put HOST_IP on the lidar NIC ourselves. The container is privileged +
# network_mode host, so this configures the HOST interface with NO sudo and
# NO host-side script — it travels with the stack (works on the Jetson too).
# The NIC is auto-detected (non-default-route wired iface). The 255.255.255.255
# broadcast route is intentionally NOT set: diagnostics proved it irrelevant to
# the unicast Mid-360 config (KNOWN_ISSUES.md #1). Best-effort: a missing NIC
# / no lidar must never block the container from starting.
( set +e
  [ -f /work/config/stack.env ] && . /work/config/stack.env
  HOST_IP="${HOST_IP:-192.168.1.5}"
  if ip -4 addr show 2>/dev/null | grep -q "inet ${HOST_IP}/"; then
    echo "[entrypoint] ${HOST_IP} already configured; skipping NIC setup"
  else
    defif=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
    nic=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' \
            | grep -E '^(en|eth)' | grep -vx "${defif:-}" | head -1)
    nic="${nic:-enp4s0}"
    if ip link show "$nic" >/dev/null 2>&1; then
      ip link set "$nic" up 2>/dev/null
      if ip addr replace "${HOST_IP}/24" dev "$nic" 2>/dev/null; then
        echo "[entrypoint] lidar NIC ${nic} <- ${HOST_IP}/24"
      else
        echo "[entrypoint] WARN: failed to set ${HOST_IP} on ${nic}"
      fi
    else
      echo "[entrypoint] WARN: no lidar NIC found (tried ${nic}); skipped"
    fi
  fi
)

exec "$@"
