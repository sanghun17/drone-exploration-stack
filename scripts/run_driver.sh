#!/bin/bash
# Launch the Mid-360(S) driver INSIDE the dev container:
#   docker compose exec dev bash /work/scripts/run_driver.sh
#
# Uses an ISOLATED ROS master on :11399. This is deliberate: if the host runs
# another roscore (e.g. a simulation with /use_sim_time + /clock), joining it
# silently breaks `rostopic hz` and TF on the real lidar. Override with
# ROS_MASTER_PORT=11311 to use the default master instead.
set -e
PORT="${ROS_MASTER_PORT:-11399}"
export ROS_MASTER_URI="http://localhost:${PORT}"

source /opt/ros/noetic/setup.bash
source /work/ros_ws/devel/setup.bash

# Single source of truth for the lidar config is /work/config.
cp -f /work/config/MID360_config.json \
      /work/ros_ws/src/livox_ros_driver2/config/MID360_config.json

if ! pgrep -f "roscore -p ${PORT}" >/dev/null 2>&1; then
  roscore -p "${PORT}" >/tmp/roscore_${PORT}.log 2>&1 &
  sleep 4
fi

exec roslaunch livox_ros_driver2 msg_MID360.launch
