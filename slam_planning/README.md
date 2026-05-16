# slam_planning — SCAFFOLD (not yet integrated)

This directory is a placeholder for the SLAM + planning layer that consumes the
Mid-360 point cloud / IMU produced by this stack.

Status: **not implemented yet.** The lidar driver layer (Docker env, patched
Livox-SDK2 for Mid-360S, `livox_ros_driver2`) is working and verified
(`/livox/lidar` @ 10 Hz, `/livox/imu` @ 200 Hz). The components below are the
intended next steps and have **not** been added or tested.

## Planned components

| Component | Role | Intended integration |
|-----------|------|-----------------------|
| FAST-LIVO (FAST-LIVO2) | LiDAR-inertial-visual odometry / SLAM, consumes `/livox/lidar` + `/livox/imu` | git submodule under `slam_planning/`, built in the same catkin workspace |
| EPIC planner | Local planning on the SLAM map/odometry | git submodule under `slam_planning/`, built in the same catkin workspace |

## How they will slot in

- Add each as a `git submodule` (this repo's convention for external code),
  pinned to a known-good commit.
- FAST-LIVO subscribes to `/livox/lidar` (livox custom msg) + `/livox/imu`.
  Confirm the point type / topic names match its config.
- Build inside the same dev container via `scripts/build_workspace.sh`
  (extend it to `catkin build` these packages after the driver).
- Keep the dev loop unchanged: edit on host, `catkin build` in-container, no
  image rebuilds.

> Upstream repository URLs are intentionally left for the maintainer to fill in
> (to pin the exact forks/commits you want) — see the top-level README.
