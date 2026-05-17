# drone-exploration-stack

Dockerized aerial-autonomy stack on **ROS Noetic / Ubuntu 20.04**:

- **Livox Mid-360S** LiDAR — with a patched Livox-SDK2 (stock SDK does not work
  with Mid-360**S** units; see [Mid-360S notes](#the-mid-360s-problem)).
- **PX4 / MAVROS** (installed, link not yet verified — see [Status](#status)).
- **FAST-LIVO2** (LiDAR-inertial-visual odometry) + **EPIC planner** — cloned
  into the catkin workspace and built alongside the driver (pinned, gitignored;
  see [SLAM / planning](#slam--planning)).

Multi-target by design: **nuc (x86_64)** now, **jetson (arm64)** later. The
base image is multi-arch; nothing here is x86-only.

Architecture (env-only image + bind-mounted source + per-arch targets) follows
the pattern of the ForzaETH `race_stack`; this repo is standalone.

Verified: `/livox/lidar` @ **10 Hz**, `/livox/imu` @ **200 Hz** (19968 pts/msg,
frame `livox_frame`), measured with `rostopic hz` on an isolated ROS master.

---

## Quick start

After `git clone`: **edit one config, run one script, then one command per node.**

### 1. Configure — the only file you edit

```bash
$EDITOR config/stack.env      # HOST_IP, LIDAR_IP, FCU_URL, ROS_MASTER_PORT
```

The lidar-facing NIC is **auto-detected** (you don't set it) and there is **no
host network script and no sudo**: the container is privileged +
`network_mode host`, so `docker/ros_entrypoint.sh` puts `HOST_IP` on the lidar
NIC itself on every start (portable to the Jetson). The broadcast route is not
needed — see [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) #1.

### 2. Bootstrap — once

```bash
bash scripts/setup.sh
```

Builds the image (ROS Noetic + MAVROS + Sophus + **patched Livox-SDK2**, all
baked so they survive container recreate), starts the dev container,
auto-clones EPIC + FAST-LIVO2 + rpg_vikit, generates `MID360_config.json` from
`stack.env`, and catkin-builds the whole workspace.

### 3. Run each node — one host command each

```bash
bash scripts/run_lidar.sh        # Livox Mid-360 driver
bash scripts/run_fastlivo.sh     # FAST-LIVO2 (LIO)
bash scripts/run_epic.sh         # EPIC planner
bash scripts/run_mavros.sh       # PX4 MAVROS
bash scripts/run_rviz.sh         # RViz (integrated view)
```

Each `run_*.sh` auto-jumps into the dev container and shares the isolated ROS
master `:11399`. Change IPs/serial → edit `config/stack.env`, re-run
`scripts/run_lidar.sh`. Code changes → re-run `scripts/setup.sh`. **No image
rebuilds** for source changes — only for env changes (`docker/Dockerfile`).

> ⚠️ Open issue: `/livox/lidar` may publish no points (IMU works) — lidar &
> network are proven fine; under investigation in the Livox SDK/driver layer.
> See [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) #1.

### Multi-arch build (for the jetson target later)

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -f docker/Dockerfile -t drone-exploration-stack:noetic ..
```

---

## The Mid-360S problem

This unit reports **`dev_type = 35` (Mid-360S)**, not `9` (plain Mid-360).
Stock Livox-SDK2 (incl. the latest v1.3.1) only routes `dev_type 9` through its
command/data handlers, so a Mid-360S is **discovered but never connects** — no
point cloud, no error (Livox `livox_ros_driver2` issue #240).

**Do not flash the lidar firmware** — issue #240 shows that path fails
(`ret_code 50`) and risks the unit. The fix is a source patch, vendored here in
`third_party/Livox-SDK2/` and recorded in
`patches/livox-sdk2-mid360s-devtype.patch`:

> Normalize `dev_type 35 → 9` at **both** detection chokepoints —
> `sdk_core/device_manager.cpp` (before the `type_lidars_cfg_map_.find` in the
> detection-receive loop) **and**
> `sdk_core/command_handler/general_command_handler.cpp`
> (`HandleDetectionData`). Patching only one is insufficient — `device_manager`
> drops the packet first.

After the patch the full handshake completes (detection → fw query → work mode
Normal → data channels) and data streams normally.

## Networking (multi-homed host)

The host has two NICs: one to the internet, one to the lidar (*multi-homed*).
The Mid-360 unicasts to a fixed host IP, so the lidar NIC just needs
`HOST_IP/24`. The container does this itself at startup (privileged +
`network_mode host`) — **no sudo, no host script**. The limited-broadcast
`255.255.255.255` route was long assumed necessary but diagnostics proved it
**irrelevant** to the unicast config (see [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md)
#1); only the static IP matters. `scripts/livox_net_setup.sh` remains as an
**optional** bare-metal-only helper (persistent NM profile) for running the
lidar without the container.

## Isolated ROS master (important)

Every `scripts/run_*.sh` shares one roscore on **:11399** (from
`config/stack.env`). It is deliberately not the default `:11311` so the real
stack never joins a stray sim roscore (`/use_sim_time` + `/clock`), which
silently breaks `rostopic hz`/TF. Override via `ROS_MASTER_PORT` in
`config/stack.env`.

---

## Layout

```
docker/        Dockerfile (multi-arch; bakes Sophus + patched Livox-SDK2) + compose + entrypoint
scripts/       setup.sh (one-time bootstrap, host)
               run_{lidar,fastlivo,epic,mavros,rviz}.sh  (host, one per node)
               build_workspace.sh · clone_{epic,fastlivo}.sh · livox_net_setup.sh (optional)
config/        stack.env (the only file you edit) · MID360_config.json.in (template;
               MID360_config.json is generated from it + stack.env, gitignored)
patches/       livox-sdk2-mid360s-devtype.patch · sophus-a621ff-ubuntu20.patch
third_party/   Livox-SDK2  (vendored, PATCHED for Mid-360S)
ros_ws/src/    livox_ros_driver2  (vendored, unmodified, ROS1)
               fast_livo2_custom · rpg_vikit · EPIC_poongsan  (cloned, gitignored)
slam_planning/ notes on the SLAM / planning layer (see its README)
```

## SLAM / planning

FAST-LIVO2 and the EPIC planner are **external catkin source**, not vendored
here (same convention as the rest of the SLAM layer): each is cloned into
`ros_ws/src/`, pinned, and gitignored.

| Repo | Clone script | Pin | Catkin package(s) |
|------|--------------|-----|-------------------|
| [`sanghun17/fast_livo2_custom`](https://github.com/sanghun17/fast_livo2_custom) | `clone_fastlivo.sh` | `main` | `fast_livo` |
| [`xuankuzcr/rpg_vikit`](https://github.com/xuankuzcr/rpg_vikit) (FAST-LIVO2 fork) | `clone_fastlivo.sh` | `master` | `vikit_common`, `vikit_ros` |
| [`sanghun17/EPIC_poongsan`](https://github.com/sanghun17/EPIC_poongsan) | `clone_epic.sh` | `jetson-orin-agx` | EPIC planner stack |

**Sophus** is the third FAST-LIVO2 dependency. Unlike the above it is a pinned,
unmodified env library (strasdat `a621ff`, the non-templated/double-only build
that ships `libSophus.so` + `sophus/se3.h`), so it is **baked into the image**
(`docker/Dockerfile`) like libpcl/libeigen — not cloned — to keep the dev loop
fast. `a621ff` needs two minimal Ubuntu-20.04/GCC-9 build fixes, recorded in
`patches/sophus-a621ff-ubuntu20.patch`.

> **Runtime caveat:** `livox_ros_driver2` publishes `/livox/lidar` as
> `livox_ros_driver2/CustomMsg`, but FAST-LIVO2 subscribes to the v1
> `livox_ros_driver/CustomMsg` type (different message MD5 → no connection).
> This is a topic-wiring concern, **not** a build one — the Docker build
> integration here is independent of it. Bridge/republish wiring is a separate
> follow-up.

## Status

| Part | State |
|------|-------|
| Mid-360S → ROS (`/livox/lidar` 10 Hz, `/livox/imu` 200 Hz) | ✅ working, verified |
| Env Docker image + mounted-source dev loop | ✅ working |
| Multi-arch (nuc x86 now / jetson arm later) | ✅ supported (buildx) |
| Host net setup script (reboot-safe IP, runtime broadcast route) | ✅ working |
| PX4 / MAVROS link | ⏳ MAVROS installed, **not yet tested** (FC not connected) |
| FAST-LIVO2 builds in the image (Sophus + vikit + fast_livo) | ✅ integrated (clone + build) |
| FAST-LIVO2 ↔ Mid-360 runtime topic wiring (CustomMsg type) | ⏳ follow-up |
| EPIC planner integration | ⏳ cloned, builds with workspace |
| NM dispatcher hook (auto broadcast route on boot) | ⏳ TODO |

## Licenses / credits

`third_party/Livox-SDK2` and `ros_ws/src/livox_ros_driver2` are from
[Livox-SDK](https://github.com/Livox-SDK) (MIT). Livox-SDK2 is **modified** —
the Mid-360S `dev_type` normalization; original `LICENSE.txt` retained, change
documented in `patches/`.

SLAM / planning source is fetched at clone time, not redistributed here:
[FAST-LIVO2](https://github.com/hku-mars/FAST-LIVO2) (**GPLv2**),
[rpg_vikit](https://github.com/xuankuzcr/rpg_vikit), and
[EPIC](https://github.com/SYSU-STAR/EPIC) (GPLv3) keep their own licenses.
Sophus ([strasdat](https://github.com/strasdat/Sophus), MIT) is built in the
image from upstream `a621ff` with only the Ubuntu-20.04 build fixes in
`patches/sophus-a621ff-ubuntu20.patch`. Note FAST-LIVO2's GPLv2 terms before
redistributing any image that bakes it in.
