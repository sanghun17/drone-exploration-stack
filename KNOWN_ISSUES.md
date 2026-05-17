# Known Issues

## 1. Mid-360: `/livox/lidar` publishes no points (IMU works) — UNRESOLVED

**Status:** Open. Diagnosed to the Livox SDK/driver application layer; root cause
within it not yet pinned. Tracked here so the diagnostics aren't repeated.

**Date:** 2026-05-17

### Symptom
- `livox_ros_driver2` connects, completes the full handshake, and publishes
  `/livox/imu` at ~200 Hz.
- `/livox/lidar` publishes **nothing** — no point messages at all.
- This **worked at the start of the session** (FAST-LIVO2 LIO processed
  `Input point number: 19968` per frame, odometry @10 Hz). It stopped after
  many container recreations/rebuilds done for the EPIC/FAST-LIVO2/X11/Sophus
  work + a host reboot + lidar power cycles. Not caused by the hardware.

### Proven OK (do NOT re-investigate these — evidence captured)
| Layer | Evidence |
|---|---|
| Lidar TX | Raw L2 sniff: lidar `192.168.1.188` sends ~2000 pkt/s, 1200-byte payloads, to `192.168.1.5:56301` (the exact configured point port) |
| Network/IP/NIC | enp4s0 `192.168.1.5/24` correct; lidar pings 1.9 ms; ARP good |
| Broadcast route | Tested route on **correct** NIC vs **wrong** NIC — *identical* result. The `255.255.255.255` route is **irrelevant** to point streaming for this unicast config. |
| rp_filter / firewall | rp_filter=2 (loose, non-blocking); iptables empty |
| Kernel delivery | `nstat` across the stream: `IpInReceives +9186/4s`, **`UdpInDatagrams +9154/4s`**, **zero** error/drop counters. Point datagrams are delivered to **and read by** the driver process (socket queue stays 0, `d0` drops). |
| Socket buffer | `net.core.rmem_max` is small (212992) but socket `d0` = **no** overflow drops → not the cause |
| SDK linkage | `livox_ros_driver2/CMakeLists.txt` links `liblivox_lidar_sdk_static.a` from `/usr/local/lib`; `build_workspace.sh` builds+installs the **patched** Livox-SDK2 (Mid-360S `dev_type 35→9`) there *before* the driver. Patch present in source (`device_manager.cpp:544`) and in the linked lib. |
| Build structure | Clean **isolated** rebuild (EPIC/FAST-LIVO2 moved out, livox-only) still fails → not the multi-package catkin build |

### Narrowed conclusion
The Livox SDK/driver **receives and reads the point UDP datagrams** but does not
turn them into `/livox/lidar` messages. Purely application/binary behaviour. The
patched SDK source is capable (it worked at session start), so this is a build /
runtime / config subtlety not pinpointable without hands-on Livox tooling.

### Recommended next steps (in order)
1. **Livox Viewer** on the Mid-360: confirm whether the unit is a Mid-360 (type 9)
   or Mid-360**S** (type 35), its firmware, and that it actually emits the point
   data type the config expects. Settles in minutes what can't be seen remotely.
2. Diff running `config/MID360_config.json` (`pcl_data_type`, `pattern_mode`,
   `host_net_info`) and the driver's data-handler against a **pristine upstream**
   `livox_ros_driver2` to catch config/format drift.
3. If the unit is a Mid-360S: verify the `35→9` patch also covers the **point
   data** path, not only the detection path (`device_manager.cpp` detection vs
   `data_handler.cpp`).

### Reproduce / verify quickly
```
docker exec dps-dev bash /work/scripts/run_driver.sh        # start driver
# IMU works, points don't:
docker exec dps-dev bash -lc 'source /opt/ros/noetic/setup.bash; \
  export ROS_MASTER_URI=http://localhost:11399; \
  rostopic hz /livox/imu; rostopic hz /livox/lidar'
```

## 2. Patched Livox-SDK2 is lost on every container recreate (fragility)

**Status:** Open, durable fix recommended.

`scripts/build_workspace.sh` builds + `make install`s the patched Livox-SDK2
into the **container's** `/usr/local/lib` at *runtime*. That path is **not**
baked into the image and **not** bind-mounted, so **every `docker compose up`
recreate silently wipes it** until `build_workspace.sh` is re-run. This caused a
previously-working lidar to break mid-session after container recreates for the
X11/Sophus work.

**Recommended fix:** bake the patched Livox-SDK2 build into `docker/Dockerfile`
exactly like Sophus already is (it is a pinned, patched env dependency — same
category). Then it survives recreates, is portable to the Jetson, and the whole
failure mode disappears. Same principle as keeping rviz configs in the tracked
repo, not in gitignored clones.

## 3. `scripts/livox_net_setup.sh` was reworked to be one-time/persistent

Old version needed re-running after every reboot (runtime `ip route`). Rewritten
to bake the static IP **and** the limited-broadcast route into a single
persistent NetworkManager profile + auto-detect the lidar NIC. Note: per issue
#1's diagnostics the broadcast route turned out **not** to matter for point
streaming with the unicast `MID360_config.json`; the static IP is what matters.
