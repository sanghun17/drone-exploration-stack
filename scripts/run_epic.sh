#!/bin/bash
# EPIC planner (consumes FAST-LIVO2).  Run from the HOST:  bash scripts/run_epic.sh
# Trigger exploration with a 2D Nav Goal in RViz (Fixed Frame camera_init).
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

if ! pgrep -f "roscore -p ${PORT}" >/dev/null 2>&1; then
  roscore -p "${PORT}" >/tmp/roscore_${PORT}.log 2>&1 &
  sleep 4
fi

exec roslaunch /work/slam_planning/epic/epic_mid360_lio.launch
