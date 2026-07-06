#!/bin/bash
# Build libFNA3D.so.0 (FNA3D 24.04 + ASTC surface formats) for aarch64/SDL2.
#
# The additions live in fna3d-astc-r8.patch (a plain unified diff next to
# this script). They add SurfaceFormat values 25-28 (Astc4x4/5x5/6x6/8x8),
# matching the XNB format indices FNARepacker writes, plus 29 (R8, an RHH
# extension for palette-index/font single-channel textures - GL_R8 with a
# RRRR texture swizzle so shaders reading .y/.z/.w still see the R value) -
# to the enum, the block-size/format-size helpers, and the OpenGL format
# tables. MCI is GL/GLES-only (the launcher forces FNA3D_FORCE_DRIVER=OpenGL),
# so the patch touches no Vulkan or D3D11 paths.
# The patch targets the pinned upstream FNA3D 24.04 tag.

set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq >/dev/null
apt-get install -y -qq --no-install-recommends \
    build-essential cmake ninja-build git ca-certificates pkg-config libsdl2-dev >/dev/null

cd /tmp
git clone --recursive --depth 1 -b 24.04 https://github.com/FNA-XNA/FNA3D.git
cd FNA3D

git apply /host/fna3d-astc-r8.patch

# GL/GLES-only build: drop the Vulkan driver. MCI forces FNA3D_FORCE_DRIVER=
# OpenGL so the Vulkan path never instantiates, and FNA3D_Driver_Vulkan.c is
# fully guarded by #if FNA3D_DRIVER_VULKAN — undefining the macro compiles the
# driver out and drops it from the registration, leaving just OpenGL.
sed -i '/-DFNA3D_DRIVER_VULKAN/d' CMakeLists.txt

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build build --parallel

cp -v build/libFNA3D.so.0.* /host/
readelf -d build/libFNA3D.so.0.* | grep -E "NEEDED.*SDL"
