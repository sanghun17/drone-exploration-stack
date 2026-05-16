# slam_planning — notes on the SLAM / planning layer

This directory holds **notes only**. The actual SLAM + planning code is not
kept here — following this stack's convention, external catkin source is
cloned into `ros_ws/src/`, pinned, and gitignored (see the top-level README
[SLAM / planning](../README.md#slam--planning) section).

## What runs the SLAM / planning layer

| Piece | Where it comes from | Lives in |
|-------|---------------------|----------|
| FAST-LIVO2 (`fast_livo`) — LiDAR-inertial-visual odometry | `scripts/clone_fastlivo.sh` → `sanghun17/fast_livo2_custom@main` | `ros_ws/src/fast_livo2_custom/` (gitignored) |
| rpg_vikit (`vikit_common`, `vikit_ros`) — FAST-LIVO2 dep | `scripts/clone_fastlivo.sh` → `xuankuzcr/rpg_vikit@master` | `ros_ws/src/rpg_vikit/` (gitignored) |
| Sophus `a621ff` — FAST-LIVO2 dep (`libSophus.so`) | baked into the env image | `docker/Dockerfile` → `/opt/Sophus`, installed to `/usr/local` |
| EPIC planner | `scripts/clone_epic.sh` → `sanghun17/EPIC_poongsan@jetson-orin-agx` | `ros_ws/src/EPIC_poongsan/` (gitignored) |

## How it builds

`build_workspace.sh` builds the patched Livox-SDK2, then
`livox_ros_driver2/build.sh ROS1` `catkin_make`s the **whole** `ros_ws/src` —
so once cloned, FAST-LIVO2 + rpg_vikit + EPIC build in dependency order with no
extra steps. The dev loop is unchanged: edit on host, rebuild in-container, no
image rebuilds (image rebuilds are only for environment changes such as
Sophus / apt deps in `docker/Dockerfile`).

```bash
bash scripts/clone_fastlivo.sh                                  # host: FAST-LIVO2 + rpg_vikit
bash scripts/clone_epic.sh                                      # host: EPIC
docker compose exec dev bash /work/scripts/build_workspace.sh   # container: build all
```

## Open follow-up (runtime, not build)

FAST-LIVO2 subscribes to the **v1** `livox_ros_driver/CustomMsg` type, while
`livox_ros_driver2` publishes `livox_ros_driver2/CustomMsg`. The message
bodies are identical but the ROS type name / MD5 differs, so a subscriber will
not connect without a bridge or a republish. This is purely a topic-wiring
task and is independent of the Docker build integration, which is complete.
