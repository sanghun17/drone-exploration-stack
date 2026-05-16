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

# livox_ros_driver2/build.sh ROS1 wipes ros_ws/{build,devel,install} and runs
# `catkin_make` from ros_ws — i.e. it builds the WHOLE workspace, not just the
# driver. So every catkin package present in ros_ws/src is built here in
# dependency order: livox_ros_driver2, plus (if cloned) EPIC_poongsan and
# FAST-LIVO2 + rpg_vikit. Sophus is provided by the image (docker/Dockerfile).
[ -d /work/ros_ws/src/fast_livo2_custom ] && [ -d /work/ros_ws/src/rpg_vikit ] \
  || echo ">> NOTE: FAST-LIVO2 not present — run 'bash scripts/clone_fastlivo.sh' on the host to include it (build continues without it)."
[ -d /work/ros_ws/src/EPIC_poongsan ] \
  || echo ">> NOTE: EPIC planner not present — run 'bash scripts/clone_epic.sh' on the host to include it (build continues without it)."

echo ">> catkin_make whole workspace via livox_ros_driver2/build.sh (ROS1)"
cd /work/ros_ws/src/livox_ros_driver2
sed -i 's/\r$//' build.sh && chmod +x build.sh
./build.sh ROS1

test -x /work/ros_ws/devel/lib/livox_ros_driver2/livox_ros_driver2_node \
  && echo ">> OK: livox_ros_driver2 built."

if [ -d /work/ros_ws/src/fast_livo2_custom ]; then
  test -x /work/ros_ws/devel/lib/fast_livo/fastlivo_mapping \
    && echo ">> OK: FAST-LIVO2 (fastlivo_mapping) built." \
    || { echo ">> ERROR: fast_livo2_custom present but fastlivo_mapping not built."; exit 1; }
fi

if [ -d /work/ros_ws/src/EPIC_poongsan ]; then
  test -x /work/ros_ws/devel/lib/epic_planner/exploration_node \
    && echo ">> OK: EPIC planner (exploration_node) built." \
    || { echo ">> ERROR: EPIC_poongsan present but exploration_node not built."; exit 1; }
fi
