#!/bin/bash
# Livox Mid-360 driver.  Run from the HOST:  bash scripts/run_lidar.sh
# (auto-jumps into the dev container; one uniform command per node.)
set -e

if [ ! -f /.dockerenv ]; then
  REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  T=$([ -t 1 ] || echo "-T")
  exec docker compose -f "${REPO}/docker/docker-compose.yml" exec ${T} dev \
       bash "/work/scripts/$(basename "${BASH_SOURCE[0]}")" "$@"
fi

# ---- in dev container ----
. /work/config/stack.env
PORT="${ROS_MASTER_PORT:-11399}"
export ROS_MASTER_URI="http://localhost:${PORT}"
source /opt/ros/noetic/setup.bash
source /work/ros_ws/devel/setup.bash

# Generate the Mid-360 config from the template + global stack.env, so the IPs
# always match HOST_IP/LIDAR_IP with nothing hand-edited.
sed -e "s/__HOST_IP__/${HOST_IP}/g" -e "s/__LIDAR_IP__/${LIDAR_IP}/g" \
    /work/config/MID360_config.json.in > /work/config/MID360_config.json
cp -f /work/config/MID360_config.json \
      /work/ros_ws/src/livox_ros_driver2/config/MID360_config.json

# Isolated shared master on :PORT (see header of any run_*.sh for why).
if ! pgrep -f "roscore -p ${PORT}" >/dev/null 2>&1; then
  roscore -p "${PORT}" >/tmp/roscore_${PORT}.log 2>&1 &
  sleep 4
fi

exec roslaunch livox_ros_driver2 msg_MID360.launch
