#!/bin/bash
# Launch MAVROS against the PX4 flight controller INSIDE the dev container:
#   docker compose exec dev bash /work/scripts/run_mavros.sh
#
# Shares the SAME isolated ROS master on :11399 as run_driver.sh so the SLAM /
# planner stack sees the lidar AND the FC on one master. Override the master
# with ROS_MASTER_PORT=11311, or the serial link with FCU_URL.
#
# The PX4 link is a binary MAVLink stream over the CH340 USB-serial adapter
# (/dev/ttyUSB0) at 921600 baud — confirmed by garbage from `cat /dev/ttyUSB0`.
set -e
PORT="${ROS_MASTER_PORT:-11399}"
export ROS_MASTER_URI="http://localhost:${PORT}"

# Serial FCU link. PX4 companion-computer rate is 921600 on this adapter.
FCU_URL="${FCU_URL:-/dev/ttyUSB0:921600}"

source /opt/ros/noetic/setup.bash
source /work/ros_ws/devel/setup.bash

if ! pgrep -f "roscore -p ${PORT}" >/dev/null 2>&1; then
  roscore -p "${PORT}" >/tmp/roscore_${PORT}.log 2>&1 &
  sleep 4
fi

# px4.launch is the PX4-flavoured MAVROS launch (correct plugin set/blacklist).
# gcs_url left empty: no GCS forwarding, this is an onboard companion link.
exec roslaunch mavros px4.launch fcu_url:="${FCU_URL}" gcs_url:=""
