# Environment ONLY: Ubuntu 20.04 + ROS Noetic + MAVROS + build deps.
#
# App source (livox_ros_driver2, SLAM/planner) is NOT baked in — it is
# bind-mounted and built inside the running container, so iterating on code does
# not require an image rebuild. Pinned env deps (Sophus, the PATCHED Livox-SDK2)
# ARE baked, so they survive container recreate (see KNOWN_ISSUES.md #2).
#
# Multi-target: the ros:noetic-ros-base-focal base is multi-arch, so the same
# Dockerfile builds for nuc (x86_64) now and jetson (arm64) later via
# `docker buildx build --platform linux/amd64,linux/arm64`.

FROM ros:noetic-ros-base-focal

SHELL ["/bin/bash", "-lc"]
ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=noetic

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake git wget curl ca-certificates \
        iputils-ping net-tools usbutils iproute2 \
        libeigen3-dev libpcl-dev libyaml-cpp-dev libfmt-dev \
        libgeographic-dev geographiclib-tools \
        python3-catkin-tools python3-rosdep \
        ros-noetic-pcl-ros ros-noetic-pcl-conversions ros-noetic-eigen-conversions \
        ros-noetic-cv-bridge ros-noetic-image-transport ros-noetic-cmake-modules \
        ros-noetic-rviz ros-noetic-geometry ros-noetic-tf2-geometry-msgs \
        libopencv-dev libarmadillo-dev qtbase5-dev \
        ros-noetic-mavlink ros-noetic-mavros ros-noetic-mavros-extras \
    && geographiclib-get-geoids egm96-5 \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Sophus — environment dependency for FAST-LIVO2 (slam_planning layer).
#
# FAST-LIVO2 + rpg_vikit require the NON-templated / double-only Sophus
# (strasdat @ a621ff): it builds a real libSophus.so and ships sophus/se3.h
# (the modern header-only Sophus has neither, and would not link). This is a
# pinned, unmodified upstream env lib (not source we iterate on), so it is
# baked into the image like libpcl/libeigen — keeping the bind-mounted dev
# loop fast. Pattern follows the canonical rosblox/ros-fast-livo Dockerfile.
#
# a621ff does not compile on Ubuntu 20.04 / GCC 9 as-is; two minimal,
# upstream-agnostic build fixes are applied (see patches/sophus-a621ff-ubuntu20.patch):
#   * so2.cpp ctor: std::complex::real()/imag() are not lvalues in C++11+
#   * drop -Werror so newer Eigen/GCC warnings don't fail the build
# /opt/Sophus is kept so the build-tree SophusConfig (registered via
# export(PACKAGE Sophus) into /root/.cmake) resolves at catkin time.
# ---------------------------------------------------------------------------
RUN git clone https://github.com/strasdat/Sophus.git /opt/Sophus \
    && cd /opt/Sophus \
    && git checkout a621ff \
    && sed -i 's|unit_complex_\.real() = 1\.;|unit_complex_ = std::complex<double>(1., 0.);|' sophus/so2.cpp \
    && sed -i '/unit_complex_\.imag() = 0\.;/d' sophus/so2.cpp \
    && sed -i 's/ -Werror//g' CMakeLists.txt \
    && mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release >/dev/null \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig

# ---------------------------------------------------------------------------
# Patched Livox-SDK2 — environment dependency for livox_ros_driver2.
#
# The repo vendors a PATCHED Livox-SDK2 (third_party/Livox-SDK2) with the
# Mid-360S `dev_type 35->9` fix in sdk_core/device_manager.cpp. It is a pinned,
# patched env lib (not code we iterate on) so it is baked here like Sophus.
#
# Why baked (not built at runtime): build_workspace.sh used to `make install`
# it into the container's /usr/local/lib at runtime — which is wiped on every
# container recreate, silently breaking a working lidar (KNOWN_ISSUES.md #2).
# Baking it makes it recreate-safe and portable to the Jetson.
# ---------------------------------------------------------------------------
COPY third_party/Livox-SDK2 /opt/Livox-SDK2
RUN cd /opt/Livox-SDK2 \
    && rm -rf build && mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release >/dev/null \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig

COPY docker/ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh

WORKDIR /work
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
