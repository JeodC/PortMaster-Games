# Trixie (Debian 13) gives us clang-19 + gcc-14 + libstdc++-14 in main with
# full C++20/23 support — Dusklight uses <format> which only lives in
# libstdc++ 13+, so bookworm's stock toolchain wouldn't build it. Glibc
# floor is 2.41; port.json's min_glibc reflects that.
FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# Toolchain + Aurora's link-time deps + the full X11/Wayland/audio/input
# stack SDL3 expects on Linux. SDL3 (vendored by Aurora) auto-detects each
# subsystem and fails configure when any is missing rather than skipping.
# This list mirrors upstream Dusklight's CI install step so we surface the same
# set of capabilities.
#
# llvm-19 supplies llvm-ar-19 / llvm-ranlib-19 — required when
# CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON (build.txt) because regular `ar`
# can't index LLVM bitcode .o files produced by ThinLTO. Without it,
# CMake leaves CMAKE_CXX_COMPILER_AR=NOTFOUND and the abseil static-lib
# link step fails with `CMAKE_CXX_COMPILER_AR-NOTFOUND: not found`.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates wget curl git zip unzip pkg-config \
        build-essential cmake ninja-build make \
        clang-19 lld-19 llvm-19 clang-tools-19 \
        libvulkan-dev \
        libcurl4-openssl-dev libpng-dev libfreetype-dev libjpeg-dev \
        libgtk-3-dev \
        libssl-dev zlib1g-dev libglu1-mesa-dev libdbus-1-dev \
        libxi-dev libxrandr-dev libxinerama-dev libxcursor-dev libxss-dev \
        libx11-xcb-dev libxkbcommon-dev libwayland-dev libdecor-0-dev \
        libasound2-dev libpulse-dev libudev-dev libusb-1.0-0-dev \
        libpipewire-0.3-dev libncurses-dev \
        autoconf automake libtool python3 python3-markupsafe \
    && update-alternatives --install /usr/bin/ld.lld ld.lld /usr/bin/ld.lld-19 100 \
    && update-alternatives --install /usr/bin/lld lld /usr/bin/lld-19 100 \
    && rm -rf /var/lib/apt/lists/*

# Aurora's `nod` (GameCube/Wii ISO reader) is written in Rust. On linux-aarch64
# there's no prebuilt nod release, so Aurora's auto-resolver picks vendor mode
# and Corrosion compiles nod from source — needs rustc + cargo. Trixie's apt
# rustc is recent (1.75+) but rustup gives us the latest stable for free and
# matches what Aurora's nod is tested against.
#
# Install to /opt (NOT $HOME/.cargo) because docker-setup.sh bind-mounts the
# host project root onto /root at run-time, which would mask /root/.cargo/.
# /opt is untouched by the bind mount so Corrosion can find rustc/cargo.
ENV CARGO_HOME=/opt/cargo \
    RUSTUP_HOME=/opt/rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path \
    && /opt/cargo/bin/rustc --version
ENV PATH="/opt/cargo/bin:${PATH}"

WORKDIR /root

CMD ["bash"]
