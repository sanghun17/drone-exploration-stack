#!/bin/bash
# rviz INSIDE the dev container, drawn on THIS host's screen via X11.
# Run on the HOST (it needs the host-side `xhost` grant):
#
#   bash scripts/run_rviz.sh              # integrated config (default):
#                                         #   FAST-LIVO2 cloud+odom + EPIC
#                                         #   map/frontiers/tour/trajectory,
#                                         #   Fixed Frame camera_init.
#   bash scripts/run_rviz.sh epic         # your EPIC config (adopted, camera_init)
#   bash scripts/run_rviz.sh fastlivo     # your FAST-LIVO2 sr.rviz (adopted, no image)
#   bash scripts/run_rviz.sh /work/abs/path.rviz
#   RVIZ_CONFIG=/work/x.rviz bash scripts/run_rviz.sh
#
# Requires: the /tmp/.X11-unix mount in docker/docker-compose.yml and a
# running dps-dev. GPU/GL is free because the container is privileged
# (/dev/dri). Shares the isolated ROS master :11399 (ROS_MASTER_PORT to
# override). NOTE: X11 needs a display on THIS machine — on a headless
# Jetson use foxglove instead; rviz-in-docker is for GUI workstations only.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE="${SCRIPT_DIR}/../docker/docker-compose.yml"
PORT="${ROS_MASTER_PORT:-11399}"

case "${1:-integrated}" in
  integrated) CFG="/work/slam_planning/rviz/epic_fastlivo.rviz" ;;  # EPIC folders + FAST-LIVO2 folder
  epic)       CFG="/work/slam_planning/rviz/epic.rviz" ;;            # your EPIC config (frame->camera_init)
  fastlivo)   CFG="/work/slam_planning/rviz/fastlivo.rviz" ;;        # your sr.rviz minus image
  *)          CFG="$1" ;;
esac
CFG="${RVIZ_CONFIG:-$CFG}"

# Host side: let the container's root user reach this X server. Idempotent.
xhost +local:root >/dev/null 2>&1 || echo ">> WARN: xhost unavailable — X11 may be denied"

echo ">> rviz in dps-dev | DISPLAY=${DISPLAY:-:0} | master :${PORT} | cfg ${CFG}"
exec docker compose -f "${COMPOSE}" exec dev bash -lc "
  source /opt/ros/noetic/setup.bash
  source /work/ros_ws/devel/setup.bash
  export ROS_MASTER_URI=http://localhost:${PORT}
  export DISPLAY=${DISPLAY:-:0}
  exec rviz -d '${CFG}'
"
