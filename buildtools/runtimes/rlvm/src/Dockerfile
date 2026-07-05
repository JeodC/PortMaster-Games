# SuperEngine (rlvm successor) runtime build environment.
#
# Why not FROM rhh-base: rhh-base is Ubuntu 20.04 with GCC 9.4. SuperEngine
# requires C++20 <format> (GCC 13+). Ubuntu 24.04 ships GCC 13 which is fine.
#
# Why ubuntu:24.04 directly: the build_runtimes.yml workflow runs on
# ubuntu-24.04-arm (native aarch64 GitHub runner), so an aarch64 Ubuntu
# image is pulled and used natively — no qemu emulation, no cross-compile.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget git file \
        build-essential pkg-config make cmake ninja-build \
        libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev \
        libboost-program-options-dev libboost-serialization-dev \
        libboost-iostreams-dev libboost-filesystem-dev \
        libboost-log-dev libboost-date-time-dev libboost-system-dev \
        libgl1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev \
        libvorbis-dev zlib1g-dev libfreetype6-dev gettext \
        libjpeg-dev \
        squashfs-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root
CMD ["bash"]
