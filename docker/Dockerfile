# Environment ONLY: Ubuntu 20.04 + ROS Noetic + MAVROS + build deps.
#
# Source (Livox-SDK2, livox_ros_driver2, SLAM/planner) is NOT baked in — it is
# bind-mounted and built inside the running container, so iterating on code does
# not require an image rebuild.
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
        libeigen3-dev libpcl-dev libyaml-cpp-dev \
        libgeographic-dev geographiclib-tools \
        python3-catkin-tools python3-rosdep \
        ros-noetic-pcl-ros ros-noetic-pcl-conversions ros-noetic-eigen-conversions \
        ros-noetic-mavlink ros-noetic-mavros ros-noetic-mavros-extras \
    && geographiclib-get-geoids egm96-5 \
    && rm -rf /var/lib/apt/lists/*

COPY docker/ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh

WORKDIR /work
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
