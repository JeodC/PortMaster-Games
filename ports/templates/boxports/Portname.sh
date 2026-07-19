#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# Variables
GAMEDIR="/$directory/ports/portfolder"
GAME="$GAMEDIR/data/GameBinary.x86_64"   # user-provided Linux build (x86_64 OR 32-bit x86)
BOX64="$HOME/box/box64"

# CD and set log
cd "$GAMEDIR/data"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Permissions
chmod +x "$GAME"

# Pre-flight checks for X11 and OpenGL
if [ -z "$DISPLAY" ]; then
    echo "Error: Display manager not found. This game requires OpenGL and X11 to run."
    exit 1
fi

if ! command -v glxinfo >/dev/null 2>&1; then
    echo "Error: OpenGL not found. This game requires OpenGL and X11 to run."
    exit 1
fi

# Optional: spoof GL version on devices with old Mesa (< 3.3).
# Needed for Unity games that probe minimum GL version at startup.
# Uncomment if the game refuses to launch on lowres/older devices.
# version=$(glxinfo | grep -oP 'OpenGL version string: \K[0-9]+\.[0-9]+' | head -n 1)
# major=${version%%.*}
# minor=${version#*.}
# if [ "$major" -lt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -lt 3 ]; }; then
#     export MESA_GL_VERSION_OVERRIDE=3.3
#     export MESA_GLSL_VERSION_OVERRIDE=330
#     export MESA_NO_ASYNC_COMPILE=1
#     echo "[WARNING] Overriding GL version to run the game; may cause perf or visual issues."
# fi

# Mount box runtime
BOX="$HOME/box"
BOX_RUNTIME="$controlfolder/libs/box.squashfs"
if [ -f "$BOX_RUNTIME" ]; then
    $ESUDO mkdir -p "$BOX"
    $ESUDO umount "$BOX" 2>/dev/null || true
    $ESUDO mount "$BOX_RUNTIME" "$BOX"
else
    pm_message "This port requires the box runtime. Please update PortMaster."
    pm_finish
    exit 1
fi

# Exports
export BOX64_LD_LIBRARY_PATH="$BOX/box64-i386-linux-gnu:$BOX/box64-x86_64-linux-gnu:$GAMEDIR/libs.aarch64:$GAMEDIR/data"
export XDG_CONFIG_HOME="$GAMEDIR/saves" && mkdir -p "$GAMEDIR/saves"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
export SDL_VIDEODRIVER="x11"

# Box64 dynarec tuning — see https://github.com/ptitSeb/box64/blob/main/docs/USAGE.md
export BOX64_NOBANNER=1                # Hide Box64 startup banner (cleaner logs)
export BOX64_DYNAREC=1                 # Enable the JIT dynarec for x86 -> ARM
export BOX64_DYNAREC_SAFEFLAGS=0       # Skip extra flag-preservation checks for speed
export BOX64_DYNAREC_FASTROUND=1       # Fast (non-IEEE) FP rounding — set to 0 if game misbehaves
export BOX64_DYNAREC_BIGBLOCK=1        # Merge more instructions per block
export BOX64_DYNAREC_CALLRET=1         # CALL/RET optimization — set to 2 for more compatibility
export BOX64_DYNAREC_DIRTY=1
export BOX64_DYNAREC_FORWARD=128       # Scan N bytes ahead to extend blocks; weaker CPUs may want lower
export BOX64_RDTSC_1GHZ=1              # Emulate RDTSC at 1 GHz for predictable timing
export BOX64_VSYNC=0                   # Let the engine control vsync

# Optional: OpenGL/Mesa error suppression (minor perf gain)
# export LIBGL_NOERROR=1
# export MESA_NO_ERROR=1

# Optional: Unity-specific tweaks (uncomment for Unity games)
# export UNITY_DISABLE_PARTICLES=0
# export __GL_THREADED_OPTIMIZATIONS=1

# Optional: extra compat knobs some games need (rare, comment in only if required)
# export BOX64_DYNAREC_STRONGMEM=0
# export BOX64_DYNAREC_WAIT=1
# export BOX64_DYNAREC_X87DOUBLE=0
# export BOX64_DYNAREC_FASTNAN=1
# export BOX64_PREFER_WRAPPED=1
# export BOX64_PREFER_EMULATED=0
# export BOX64_NOSIGSEGV=1

# Optional: display loading splash from the box runtime (long load times)
# [ "$CFW_NAME" == "muOS" ] && $ESUDO "$BOX/splash" "$GAMEDIR/splash.png" 1
# $ESUDO "$BOX/splash" "$GAMEDIR/splash.png" 30000 &

# Run it
$GPTOKEYB "$GAME" -c "$GAMEDIR/game.gptk" &
pm_platform_helper "$GAME" > /dev/null
$BOX64 "$GAME"

# Cleanup
$ESUDO umount "$BOX" 2>/dev/null
pm_finish
