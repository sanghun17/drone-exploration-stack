#!/bin/bash
# One-time (or after SDK/driver source changes) build, run INSIDE the dev
# container:  docker compose exec dev bash /work/scripts/build_workspace.sh
set -e
source /opt/ros/noetic/setup.bash

echo ">> Building + installing patched Livox-SDK2 (Mid-360S dev_type 35->9)"
cd /work/third_party/Livox-SDK2
rm -rf build && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release >/dev/null
make -j"$(nproc)"
make install
ldconfig

echo ">> catkin build livox_ros_driver2 (ROS1)"
cd /work/ros_ws/src/livox_ros_driver2
sed -i 's/\r$//' build.sh && chmod +x build.sh
./build.sh ROS1

test -x /work/ros_ws/devel/lib/livox_ros_driver2/livox_ros_driver2_node \
  && echo ">> OK: workspace built."
