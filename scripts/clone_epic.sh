#!/bin/bash
# Clone the EPIC exploration planner into the catkin workspace so
# build_workspace.sh builds it alongside the Mid-360 driver.
#
#   bash scripts/clone_epic.sh        # run on the HOST (repo is bind-mounted)
#
# ----------------------------------------------------------------------------
#  PINNED BRANCH — read this before changing anything
# ----------------------------------------------------------------------------
#  This stack ALWAYS uses EPIC_poongsan's `onboard-docker` branch, REGARDLESS
#  of this repo's own target-machine branch (x86 / jetson).
#
#  `onboard-docker` is purpose-built for this Dockerized real-sensor stack:
#    base   = Desktop (complete, correct tree; carries Jetson/D455 config)
#    minus  = MARSIM simulation pkgs (local_sensing[OpenGL/CUDA],
#             map_generator, mars_drone_sim, cascadePID, test_interface)
#    plus   = jetson-orin-agx versions of the 6 real-hardware/FAST-LIVO2
#             packages (exploration_manager, minco_planner, lidar_map,
#             pointcloud_topo, frontier_manager, lkh_tsp_solver)
#  The raw jetson-orin-agx branch is a broken partial flatten — do NOT pin
#  to it, nor to Desktop/main (they drag in the OpenGL simulator).
# ----------------------------------------------------------------------------
set -euo pipefail

EPIC_REPO="https://github.com/sanghun17/EPIC_poongsan"
EPIC_BRANCH="onboard-docker"           # <-- pinned, intentionally not configurable

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${SCRIPT_DIR}/../ros_ws/src/EPIC_poongsan"

if [[ -d "${DEST}/.git" ]]; then
  echo ">> EPIC present at ${DEST}; hard-syncing to ${EPIC_BRANCH}"
  # Shallow single-branch clones don't track other branches, so fetch by name
  # and pin to FETCH_HEAD (origin/<branch> may not exist). clean -fdx wipes
  # stale files when the tree layout differs between branches.
  git -C "${DEST}" fetch --depth 1 origin "${EPIC_BRANCH}"
  git -C "${DEST}" checkout -q -B "${EPIC_BRANCH}" FETCH_HEAD
  git -C "${DEST}" reset -q --hard FETCH_HEAD
  git -C "${DEST}" clean -qfdx
else
  echo ">> Cloning EPIC_poongsan@${EPIC_BRANCH} -> ${DEST}"
  git clone --depth 1 --branch "${EPIC_BRANCH}" "${EPIC_REPO}" "${DEST}"
fi

echo ">> Done: $(git -C "${DEST}" rev-parse --short HEAD) \
($(git -C "${DEST}" rev-parse --abbrev-ref HEAD))"
