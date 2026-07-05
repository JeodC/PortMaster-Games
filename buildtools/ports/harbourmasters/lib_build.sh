# Shared dependency-build helpers for HarbourMasters ports.
#
# Sourced by each port's src/build.txt at /root/buildtools/harbourmasters/lib_build.sh
# (the RHH-Ports repo root is bind-mounted at /root inside the build container).
#
# Provides:
#   project_clone               — clone the port repo, optionally with submodules,
#                                 honoring REPO_URL/REF/FORCE_HEAD
#   project_configure_and_build — cmake configure + asset-generation target + main build
#   build_<dep>                 — clone, configure, build, and install a common dep into /usr/local
#   stage_libs                  — copy host libs into $PROJECT_BUILD_DIR/libs and verify NEEDED
#
# Environment knobs:
#   PROJECT_URL  (optional) — fork URL to clone; default: caller-provided
#   REF          (optional) — branch/tag/SHA to check out
#   FORCE_HEAD   (optional) — "true" to skip latest-tag fallback and stay on HEAD
#   PROJECT_DIR=/root/build-port/project
#   DEPS_DIR=/root/build-port/deps
#   PROJECT_BUILD_DIR=$PROJECT_DIR/build

set -e

PROJECT_DIR=${PROJECT_DIR:-/root/build-port/project}
DEPS_DIR=${DEPS_DIR:-/root/build-port/deps}
PROJECT_BUILD_DIR=${PROJECT_BUILD_DIR:-$PROJECT_DIR/build}

mkdir -p "$DEPS_DIR"

# GitHub occasionally returns transient HTTP 500s during git clone. Retry with
# backoff so single failures don't abort the whole build.
git_clone_retry() {
    local attempt
    for attempt in 1 2 3 4 5; do
        if git clone "$@"; then
            return 0
        fi
        local delay=$((attempt * 5))
        echo "git clone failed (attempt $attempt); retrying in ${delay}s..." >&2
        sleep "$delay"
    done
    echo "git clone failed after 5 attempts" >&2
    return 1
}

# project_clone <default-url> [--recursive]
project_clone() {
    local default_url=$1
    local clone_flags=""
    local sm_flags="--init"
    if [[ "${2:-}" == "--recursive" ]]; then
        clone_flags="--recursive"
        sm_flags="--init --recursive"
    fi

    local url=${REPO_URL:-$default_url}
    echo ">>> project_clone: $url -> $PROJECT_DIR"
    git_clone_retry $clone_flags "$url" "$PROJECT_DIR"

    git -C "$PROJECT_DIR" fetch --tags

    if [[ -n "${REF:-}" ]]; then
        echo ">>> project_clone: checking out explicit ref $REF"
        git -C "$PROJECT_DIR" checkout "$REF"
    elif [[ "${FORCE_HEAD:-false}" == "true" ]]; then
        echo ">>> project_clone: FORCE_HEAD=true, staying on default branch HEAD"
    else
        local latest_tag
        latest_tag=$(git -C "$PROJECT_DIR" describe --tags "$(git -C "$PROJECT_DIR" rev-list --tags --max-count=1)")
        echo ">>> project_clone: checking out latest tag $latest_tag"
        git -C "$PROJECT_DIR" checkout "$latest_tag"
    fi

    # Submodule init can also hit transient HTTP 500s — retry.
    for attempt in 1 2 3 4 5; do
        if git -C "$PROJECT_DIR" submodule update $sm_flags; then break; fi
        echo "submodule update failed (attempt $attempt); retrying in $((attempt * 5))s..." >&2
        sleep $((attempt * 5))
        [[ $attempt -eq 5 ]] && { echo "submodule update failed after 5 attempts"; exit 1; }
    done
}

# project_configure_and_build <generate-target> [extra cmake -D args...]
#   <generate-target>  — name of the asset-generation target (e.g. GenerateSohOtr,
#                        GeneratePortO2R), or "" to skip
project_configure_and_build() {
    local gen_target=$1
    shift
    local cmake_args=("$@")

    if command -v clang-18 >/dev/null 2>&1; then
        export CC=clang-18
        export CXX=clang++-18
    else
        export CC=clang
        export CXX=clang++
    fi

    echo ">>> project_configure_and_build: configuring"
    cmake -S "$PROJECT_DIR" -B "$PROJECT_BUILD_DIR" -GNinja "${cmake_args[@]}"

    if [[ -n "$gen_target" ]]; then
        echo ">>> project_configure_and_build: building asset target $gen_target"
        cmake --build "$PROJECT_BUILD_DIR" --target "$gen_target" -j"$(nproc)"
    fi

    echo ">>> project_configure_and_build: building main"
    cmake --build "$PROJECT_BUILD_DIR" -j"$(nproc)"
}

# _build_dep <name> <git-url> <ref> [extra cmake -D args...]
#   Clones into $DEPS_DIR/<name>, checks out <ref>, configures into <name>/build,
#   builds, installs into /usr/local.
_build_dep() {
    local name=$1 url=$2 ref=$3
    shift 3
    local extra_args=("$@")

    local src="$DEPS_DIR/$name"
    local build="$src/build"

    if [[ -d "$src/.git" ]]; then
        echo ">>> _build_dep $name: already cloned, skipping fetch"
    else
        echo ">>> _build_dep $name: cloning $url"
        git_clone_retry "$url" "$src"
    fi

    echo ">>> _build_dep $name: checking out $ref"
    git -C "$src" checkout "$ref"

    echo ">>> _build_dep $name: configuring"
    cmake -S "$src" -B "$build" \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_TESTING=OFF \
        "${extra_args[@]}"

    echo ">>> _build_dep $name: building"
    cmake --build "$build" -j"$(nproc)"

    echo ">>> _build_dep $name: installing"
    cmake --install "$build"
}

build_sdl2() {
    _build_dep SDL https://github.com/libsdl-org/SDL.git release-2.32.0 \
        -DBUILD_SHARED_LIBS=ON \
        -DSDL_TEST=OFF \
        "$@"
}

build_sdl2_net() {
    _build_dep SDL_net https://github.com/libsdl-org/SDL_net.git release-2.2.0 \
        -DBUILD_SHARED_LIBS=ON "$@"
}

build_libzip() {
    _build_dep libzip https://github.com/nih-at/libzip.git \
        0581df510597b46c28509e9d4b5998cf5fecb636 \
        -DBUILD_TOOLS=OFF \
        -DBUILD_REGRESS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_DOC=OFF \
        -DENABLE_OPENSSL=OFF \
        -DENABLE_GNUTLS=OFF \
        -DENABLE_MBEDTLS=OFF \
        -DENABLE_COMMONCRYPTO=OFF \
        -DENABLE_WINDOWS_CRYPTO=OFF \
        "$@"
}

build_json() {
    _build_dep json https://github.com/nlohmann/json.git \
        f3dc4684b40a124cabc8554967c2cd8db54f15dd \
        -DJSON_BuildTests=OFF \
        "$@"
}

build_bzip2() {
    _build_dep bzip2 https://github.com/libarchive/bzip2.git \
        1ea1ac188ad4b9cb662e3f8314673c63df95a589 "$@"
}

# tinyxml2: the installed cmake config conflicts with libultraship's own
# find_package mechanism; rename it post-install so downstream falls through
# to libultraship's path. Matches the original hm64-builder behavior.
build_tinyxml2() {
    _build_dep tinyxml2 https://github.com/leethomason/tinyxml2.git \
        57ec94127bda7979282315b7d4b0059eeb6f3b5d \
        -DBUILD_SHARED_LIBS=ON "$@"
    local cfg="$DEPS_DIR/tinyxml2/cmake/tinyxml2-config.cmake"
    if [[ -f "$cfg" ]]; then
        mv "$cfg" "$cfg.disabled"
    fi
}

build_opus() {
    _build_dep opus https://github.com/xiph/opus.git v1.5.2 \
        -DBUILD_SHARED_LIBS=ON \
        -DOPUS_BUILD_TESTING=OFF \
        "$@"
}

# opusfile uses autotools, not cmake — keep an inline helper so callers
# can still write `build_opusfile`.
build_opusfile() {
    local src="$DEPS_DIR/opusfile"
    if [[ ! -d "$src/.git" ]]; then
        echo ">>> build_opusfile: cloning"
        git_clone_retry https://github.com/xiph/opusfile.git "$src"
    fi
    cd "$src"
    ./autogen.sh
    env -u LD PKG_CONFIG_PATH=/usr/local/lib/pkgconfig \
        ./configure --prefix=/usr/local \
            --disable-examples \
            --enable-shared --disable-static
    env -u LD make -j"$(nproc)"
    env -u LD make install
    cd - >/dev/null
}

# openssl uses its own Perl Configure, not cmake — custom helper like opusfile.
# Built from source (3.5 LTS) rather than using focal's EOL 1.1.1 so we ship a
# current, patchable, known-provenance TLS stack. Installed shared into
# /usr/local; pass -DOPENSSL_ROOT_DIR=/usr/local to the project configure so
# downstream find_package(OpenSSL) (ixwebsocket's TLS) picks this over the
# system 1.1.1. no-docs/no-tests keeps the build lean.
build_openssl() {
    local src="$DEPS_DIR/openssl"
    if [[ ! -d "$src/.git" ]]; then
        echo ">>> build_openssl: cloning"
        git_clone_retry --branch openssl-3.5.6 --depth 1 \
            https://github.com/openssl/openssl.git "$src"
    fi
    cd "$src"
    # Explicit target (don't rely on ./config auto-detect); --libdir=lib so it
    # lands in /usr/local/lib, not lib64, matching our staging + find paths.
    env -u LD ./Configure linux-aarch64 shared \
        --prefix=/usr/local \
        --openssldir=/usr/local/ssl \
        --libdir=lib \
        no-docs no-tests
    env -u LD make -j"$(nproc)"
    env -u LD make install_sw
    cd - >/dev/null
}

build_fmt() {
    _build_dep fmt https://github.com/fmtlib/fmt.git 10.1.1 \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DFMT_TEST=OFF \
        -DFMT_DOC=OFF \
        "$@"
}

build_spdlog() {
    _build_dep spdlog https://github.com/gabime/spdlog.git \
        3335c380a08c5e0f5117a66622df6afdb3d74959 \
        -DSPDLOG_BUILD_TESTS=OFF \
        -DSPDLOG_BUILD_EXAMPLE=OFF \
        "$@"
}

build_gsl() {
    _build_dep GSL https://github.com/microsoft/GSL.git \
        2828399820ef4928cc89b65605dca5dc68efca6e \
        -DBUILD_SHARED_LIBS=ON \
        -DGSL_TEST=OFF \
        "$@"
}

HM_DEVICE_PROVIDED_LIBS="libSDL2-2.0.so.0 \
    libGL.so.1 libGLESv2.so.2 libGLESv1_CM.so.1 libEGL.so.1 \
    libOpenGL.so.0 libGLdispatch.so.0 libGLX.so.0 \
    libc.so.6 libm.so.6 libpthread.so.0 libdl.so.2 librt.so.1 libresolv.so.2 \
    ld-linux-aarch64.so.1 \
    libstdc++.so.6 libgcc_s.so.1 \
    libasound.so.2 libpulse.so.0 libpulse-simple.so.0 libjack.so.0"

stage_libs() {
    local binary_rel=$1; shift
    local libs_dir="$PROJECT_BUILD_DIR/libs"
    local binary="$PROJECT_BUILD_DIR/$binary_rel"

    if [[ ! -f "$binary" ]]; then
        echo "stage_libs: ERROR: binary not found at $binary"
        exit 1
    fi

    mkdir -p "$libs_dir"

    local staged=()
    for entry in "$@"; do
        local src dest
        if [[ "$entry" == *"="* ]]; then
            src=${entry%%=*}
            dest=${entry#*=}
        else
            dest=$entry
            if [[ -f "/usr/lib/aarch64-linux-gnu/$entry" ]]; then
                src="/usr/lib/aarch64-linux-gnu/$entry"
            elif [[ -f "/usr/local/lib/$entry" ]]; then
                src="/usr/local/lib/$entry"
            else
                echo "stage_libs: ERROR: cannot locate $entry in /usr/lib/aarch64-linux-gnu or /usr/local/lib"
                exit 1
            fi
        fi
        cp -L "$src" "$libs_dir/$dest"
        staged+=("$dest")
    done

    local needed
    needed=$(readelf -d "$binary" | awk -F'[][]' '/NEEDED/ {print $2}')
    echo "Binary NEEDED:"; echo "$needed"
    echo "Staged:"; ls "$libs_dir"

    for lib in "${staged[@]}"; do
        if ! echo "$needed" | grep -qx "$lib"; then
            echo "ERROR: staged $lib but binary does not NEED it"; exit 1
        fi
        if [[ ! -f "$libs_dir/$lib" ]]; then
            echo "ERROR: $lib missing from libs/"; exit 1
        fi
    done

    # Completeness: every NEEDED entry must be staged or device-provided.
    local staged_str=" ${staged[*]} "
    local provided_str=" $HM_DEVICE_PROVIDED_LIBS "
    local unaccounted=()
    while read -r lib; do
        [[ -z "$lib" ]] && continue
        [[ "$staged_str"   == *" $lib "* ]] && continue
        [[ "$provided_str" == *" $lib "* ]] && continue
        unaccounted+=("$lib")
    done <<< "$needed"

    if (( ${#unaccounted[@]} )); then
        echo "ERROR: binary NEEDs these libs but they are neither staged nor on the device-provided allowlist:" >&2
        printf '  %s\n' "${unaccounted[@]}" >&2
        echo "Add each to the stage_libs call in build.txt, or to HM_DEVICE_PROVIDED_LIBS in lib_build.sh if every supported device already provides it." >&2
        exit 1
    fi
}
