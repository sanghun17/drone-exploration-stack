# drone-exploration-stack

Dockerized aerial-autonomy stack on **ROS Noetic / Ubuntu 20.04**:

- **Livox Mid-360S** LiDAR — with a patched Livox-SDK2 (stock SDK does not work
  with Mid-360**S** units; see [Mid-360S notes](#the-mid-360s-problem)).
- **PX4 / MAVROS** (installed, link not yet verified — see [Status](#status)).
- **FAST-LIVO + EPIC planner** — scaffolded, not yet integrated
  (`slam_planning/`).

Multi-target by design: **nuc (x86_64)** now, **jetson (arm64)** later. The
base image is multi-arch; nothing here is x86-only.

Architecture (env-only image + bind-mounted source + per-arch targets) follows
the pattern of the ForzaETH `race_stack`; this repo is standalone.

Verified: `/livox/lidar` @ **10 Hz**, `/livox/imu` @ **200 Hz** (19968 pts/msg,
frame `livox_frame`), measured with `rostopic hz` on an isolated ROS master.

---

## Quick start

### 1. Host network (once per machine, and after every reboot)

The Mid-360 is Ethernet-only on `192.168.1.0/24`. On a machine with a second
NIC (internet), the lidar NIC needs a static IP **and** a broadcast-route fix:

```bash
sudo bash scripts/livox_net_setup.sh enp4s0 192.168.1.5
```

`enp4s0` = the NIC cabled to the lidar, `192.168.1.5` = host IP (must match
`host_net_info` in `config/MID360_config.json`). See
[networking](#networking-multi-homed-host) for *why*.

### 2. Dev container (env-only image, mounted source)

```bash
cd docker
docker compose up -d                                  # build env image, start long-lived container
docker compose exec dev bash /work/scripts/build_workspace.sh   # one-time: build patched SDK2 + driver
```

### 3. Run the lidar + verify

```bash
docker compose exec dev bash /work/scripts/run_driver.sh        # streams on isolated master :11399
# in another shell:
docker compose exec dev bash -lc 'export ROS_MASTER_URI=http://localhost:11399; \
  source /work/ros_ws/devel/setup.bash; rostopic hz /livox/lidar'
```

Code changes → just re-run `build_workspace.sh` (catkin) in the container. **No
image rebuilds** for source changes — only for environment changes
(`docker/Dockerfile`).

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

The host has two NICs: one to the internet, one to the lidar — this is
*multi-homed*. Livox device discovery uses **limited broadcast
`255.255.255.255`**. With two NICs, Linux sends that out the **default-route
NIC (the internet one)** by default, so the lidar never hears it.
`scripts/livox_net_setup.sh` fixes both problems:

| Fix | Persists reboot? |
|-----|------------------|
| Static IP on the lidar NIC (NetworkManager profile `livox-mid360`) | **Yes** |
| `ip route replace 255.255.255.255/32 dev <iface>` (pin broadcast to lidar NIC) | **No** — re-run the script after reboot, or install an NM dispatcher hook (TODO) |

## Isolated ROS master (important)

`scripts/run_driver.sh` starts its own roscore on **:11399**. If another
roscore is running on the host (e.g. a simulation with `/use_sim_time` +
`/clock`), joining it silently breaks `rostopic hz` and TF for the *real*
lidar even though data is flowing. Override with `ROS_MASTER_PORT=11311`.

---

## Layout

```
docker/        env-only Dockerfile (multi-arch) + compose (dev loop) + entrypoint
scripts/       livox_net_setup.sh (host) · build_workspace.sh · run_driver.sh (container)
config/        MID360_config.json  (host IP 192.168.1.5, lidar 192.168.1.188)
patches/       livox-sdk2-mid360s-devtype.patch  (the Mid-360S fix, for reference)
third_party/   Livox-SDK2  (vendored, PATCHED for Mid-360S)
ros_ws/src/    livox_ros_driver2  (vendored, unmodified, ROS1)
slam_planning/ FAST-LIVO + EPIC planner — SCAFFOLD only (see its README)
```

## Status

| Part | State |
|------|-------|
| Mid-360S → ROS (`/livox/lidar` 10 Hz, `/livox/imu` 200 Hz) | ✅ working, verified |
| Env Docker image + mounted-source dev loop | ✅ working |
| Multi-arch (nuc x86 now / jetson arm later) | ✅ supported (buildx) |
| Host net setup script (reboot-safe IP, runtime broadcast route) | ✅ working |
| PX4 / MAVROS link | ⏳ MAVROS installed, **not yet tested** (FC not connected) |
| FAST-LIVO integration | ⏳ scaffold only |
| EPIC planner integration | ⏳ scaffold only |
| NM dispatcher hook (auto broadcast route on boot) | ⏳ TODO |

## Licenses / credits

`third_party/Livox-SDK2` and `ros_ws/src/livox_ros_driver2` are from
[Livox-SDK](https://github.com/Livox-SDK) (MIT). Livox-SDK2 is **modified** —
the Mid-360S `dev_type` normalization; original `LICENSE.txt` retained, change
documented in `patches/`.
