#!/bin/bash
set -e
source /opt/ros/noetic/setup.bash
# catkin workspace is bind-mounted at /work/ros_ws and built in-container.
if [ -f /work/ros_ws/devel/setup.bash ]; then
  source /work/ros_ws/devel/setup.bash
fi
export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}
exec "$@"
