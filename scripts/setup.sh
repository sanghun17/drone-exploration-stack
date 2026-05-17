#!/bin/bash
# ============================================================================
#  ONE-TIME bootstrap. Run on the HOST after `git clone` + editing
#  config/stack.env:
#
#      bash scripts/setup.sh
#
#  Does EVERYTHING for the environment, idempotently:
#    1. build the Docker image  (bakes ROS Noetic + MAVROS + Sophus +
#       PATCHED Livox-SDK2 + all deps)
#    2. start the dev container
#    3. build the workspace  (auto-clones EPIC + FAST-LIVO2 + rpg_vikit if
#       missing, generates the Mid-360 config from stack.env, catkin builds
#       livox driver + EPIC + FAST-LIVO2)
#
#  After this, just run the nodes (each from the HOST, one command):
#    bash scripts/run_lidar.sh   bash scripts/run_fastlivo.sh
#    bash scripts/run_epic.sh    bash scripts/run_mavros.sh
#    bash scripts/run_rviz.sh
#
#  No sudo. No host network script. The container sets the lidar NIC IP
#  itself (privileged + network_mode host) from config/stack.env.
# ============================================================================
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE="${REPO}/docker/docker-compose.yml"

[ -f "${REPO}/config/stack.env" ] || { echo "!! config/stack.env missing"; exit 1; }
echo ">> Using config/stack.env:"
grep -vE '^\s*#|^\s*$' "${REPO}/config/stack.env" | sed 's/^/     /'

echo ">> [1/3] docker compose build (image: ROS+MAVROS+Sophus+patched Livox-SDK2)"
docker compose -f "${COMPOSE}" build

echo ">> [2/3] docker compose up -d (dev container)"
docker compose -f "${COMPOSE}" up -d

echo ">> [3/3] build workspace in-container (auto-clones source, builds all)"
docker compose -f "${COMPOSE}" exec -T dev bash /work/scripts/build_workspace.sh

cat <<'DONE'

>> SETUP COMPLETE. Environment ready.

   Run each node from the host (one command, no boilerplate):
     bash scripts/run_lidar.sh        # Livox Mid-360 driver
     bash scripts/run_fastlivo.sh     # FAST-LIVO2 (LIO)
     bash scripts/run_epic.sh         # EPIC planner
     bash scripts/run_mavros.sh       # PX4 MAVROS
     bash scripts/run_rviz.sh         # RViz (integrated view)

   To change IPs / serial: edit config/stack.env, then re-run
   bash scripts/run_lidar.sh (regenerates the Mid-360 config).
DONE
