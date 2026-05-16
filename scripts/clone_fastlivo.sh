#!/bin/bash
# Clone FAST-LIVO2 (LiDAR-inertial-visual odometry) and its rpg_vikit
# dependency into the catkin workspace so build_workspace.sh builds them
# alongside the Mid-360 driver and the EPIC planner.
#
#   bash scripts/clone_fastlivo.sh        # run on the HOST (repo is bind-mounted)
#
# Same convention as scripts/clone_epic.sh: external SLAM source is NOT
# vendored into this repo; it is cloned here, pinned, and gitignored. Sophus
# (the other FAST-LIVO2 dependency) is NOT cloned here — it is a pinned env
# library baked into the Docker image (see docker/Dockerfile).
#
# ----------------------------------------------------------------------------
#  PINNED — read this before changing anything
# ----------------------------------------------------------------------------
#  * fast_livo2_custom : sanghun17's `main` (catkin package name: `fast_livo`).
#  * rpg_vikit         : xuankuzcr's `master` — the FAST-LIVO2 fork that
#                        provides vikit_common / vikit_ros (NOT the fast-livo1
#                        rpg_vikit; FAST-LIVO2's README mandates this one).
# ----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/../ros_ws/src"

clone_pinned() {
  # clone_pinned <repo-url> <branch> <dest-dir-name>
  local repo="$1" branch="$2" name="$3"
  local dest="${SRC_DIR}/${name}"
  if [[ -d "${dest}/.git" ]]; then
    echo ">> ${name} present; resetting to origin/${branch}"
    git -C "${dest}" fetch --depth 1 origin "${branch}"
    git -C "${dest}" checkout -B "${branch}" "origin/${branch}"
    git -C "${dest}" reset --hard "origin/${branch}"
  else
    echo ">> Cloning ${name}@${branch} -> ${dest}"
    git clone --depth 1 --branch "${branch}" "${repo}" "${dest}"
  fi
  echo ">> ${name}: $(git -C "${dest}" rev-parse --short HEAD) ($branch)"
}

clone_pinned "https://github.com/sanghun17/fast_livo2_custom" main   "fast_livo2_custom"
clone_pinned "https://github.com/xuankuzcr/rpg_vikit.git"     master "rpg_vikit"

echo ">> Done. Build with: docker compose exec dev bash /work/scripts/build_workspace.sh"
