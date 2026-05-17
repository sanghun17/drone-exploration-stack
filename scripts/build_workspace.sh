#!/bin/bash
# Build the catkin workspace. Normally invoked by scripts/setup.sh, but safe to
# run directly:  docker compose exec dev bash /work/scripts/build_workspace.sh
#
# - patched Livox-SDK2 is BAKED INTO THE IMAGE (docker/Dockerfile) now, so it is
#   not rebuilt here (survives container recreate; KNOWN_ISSUES.md #2). A
#   fallback build runs only if an old image lacks it.
# - EPIC / FAST-LIVO2 / rpg_vikit are auto-cloned if missing.
# - The Mid-360 config is generated from config/stack.env.
set -e
source /opt/ros/noetic/setup.bash
git config --global --add safe.directory '*' 2>/dev/null || true

# --- patched Livox-SDK2: baked in image; fallback only if missing ----------
if ! ls /usr/local/lib/liblivox_lidar_sdk_static.a >/dev/null 2>&1; then
  echo ">> Livox-SDK2 not in image (old image?) — fallback build from third_party"
  ( cd /work/third_party/Livox-SDK2 && rm -rf build && mkdir build && cd build \
      && cmake .. -DCMAKE_BUILD_TYPE=Release >/dev/null && make -j"$(nproc)" \
      && make install && ldconfig )
else
  echo ">> patched Livox-SDK2 present in image (baked)"
fi

# --- auto-clone external SLAM/planner source if missing --------------------
[ -d /work/ros_ws/src/EPIC_poongsan ] || { echo ">> cloning EPIC..."; bash /work/scripts/clone_epic.sh; }
{ [ -d /work/ros_ws/src/fast_livo2_custom ] && [ -d /work/ros_ws/src/rpg_vikit ]; } \
  || { echo ">> cloning FAST-LIVO2..."; bash /work/scripts/clone_fastlivo.sh; }

# --- generate Mid-360 config from the template + global stack.env ----------
. /work/config/stack.env
sed -e "s/__HOST_IP__/${HOST_IP}/g" -e "s/__LIDAR_IP__/${LIDAR_IP}/g" \
    /work/config/MID360_config.json.in > /work/config/MID360_config.json
cp -f /work/config/MID360_config.json \
      /work/ros_ws/src/livox_ros_driver2/config/MID360_config.json

# --- build the whole catkin workspace --------------------------------------
# livox_ros_driver2/build.sh ROS1 wipes ros_ws/{build,devel,install} and runs
# catkin_make from ros_ws -> builds every package in src: livox_ros_driver2 +
# EPIC_poongsan + FAST-LIVO2 + rpg_vikit. Sophus + Livox-SDK2 come from the image.
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
echo ">> Workspace build complete."
