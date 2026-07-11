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

source "$controlfolder/control.txt"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# Variables
GAMEDIR="/$directory/ports/zelda-lttp"
GAME="$GAMEDIR/zelda3"

# CD and set logging
cd "$GAMEDIR"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1
$ESUDO chmod +x "$GAME"

# Exports
export LD_LIBRARY_PATH="$GAMEDIR/libs:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# Device-aware config
set_ini() {
    sed -i "s|^\([[:space:]]*$1[[:space:]]*=\).*|\1 $2|" "$GAMEDIR/zelda3.ini"
}

# rk3326-class SoCs and 1GB-RAM devices are the "weak" tier: favour
# compatibility and performance over the visual extras.
is_weak_device() {
    case "$DEVICE_CPU" in
        *RK3326*|*rk3326*|*RK3036*|*RK3328*) return 0 ;;
    esac
    [ "${DEVICE_RAM:-2}" -le 1 ] 2>/dev/null && return 0
    return 1
}

# Tune zelda3.ini's display/performance settings to this device.
apply_device_config() {
    [ -f "$GAMEDIR/zelda3.ini" ] || return 0

    local mode7 samples renderer

    # Weak devices
    if is_weak_device; then
        mode7="0";  samples="2048";  renderer="SDL"
    else
        mode7="1";  samples="1024";  renderer="OpenGL ES"
    fi

    set_ini "Fullscreen"          "1"
    set_ini "EnhancedMode7"       "$mode7"
    set_ini "AudioSamples"        "$samples"
    set_ini "OutputMethod"        "$renderer"
    if [ -n "$DISPLAY_WIDTH" ] && [ -n "$DISPLAY_HEIGHT" ]; then
        set_ini "WindowSize" "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
    fi
}

apply_device_config

# Check if we need to patch the game
if [ ! -f "$GAMEDIR/zelda3_assets.dat" ]; then
    if [ -f "$controlfolder/utils/patcher.txt" ]; then
        export PATCHER_FILE="$GAMEDIR/tools/patchscript"
        export PATCHER_GAME="$(basename "${0%.*}")"
        export PATCHER_TIME="1 to 3 minutes"
        export ESUDO DEVICE_ARCH
        export controlfolder
        export directory
        $ESUDO chmod +x "$PATCHER_FILE"
        source "$controlfolder/utils/patcher.txt"
        $ESUDO kill -9 "$(pidof gptokeyb)" 2>/dev/null
    else
        pm_message "This port requires a newer version of PortMaster."
    fi
fi

# Bail if patching failed
if [ ! -f "$GAMEDIR/zelda3_assets.dat" ]; then
    pm_message "Missing game assets. Put a US 'A Link to the Past' ROM named zelda3.sfc in ports/zelda-lttp/ and relaunch. See README.md."
    pm_finish
    exit 1
fi

# Dual screen config
has_dual_screen() {
    [ "${DEVICE_HAS_DUAL_SCREEN}" = "true" ] && return 0
    [ "$(cat /sys/class/drm/card*/card*-*/status 2>/dev/null | grep -cx connected)" -ge 2 ]
}
DUALSCREEN=0
if has_dual_screen && [ ! -f "$GAMEDIR/no_dualscreen.txt" ]; then
    DUALSCREEN=1
    export ZELDA3_SECOND_SCREEN=1
    export ZELDA3_SECOND_SCREEN_TITLE="Zelda3 Bottom Screen"
    # Wayland session: let SDL pick the compositor backend
    [ -n "$WAYLAND_DISPLAY" ] && export SDL_VIDEODRIVER=wayland
    command -v swaymsg >/dev/null 2>&1 && swaymsg 'seat seat1 fallback true' >/dev/null 2>&1
fi

# Run it
$GPTOKEYB "zelda3" -c "$GAMEDIR/zelda3.gptk" &
pm_platform_helper "$GAME" >/dev/null
"$GAME"

# Cleanup
if [ "$DUALSCREEN" = "1" ] && command -v swaymsg >/dev/null 2>&1; then
    swaymsg 'seat seat1 fallback false' >/dev/null 2>&1
    swaymsg 'output DSI-1 power off' >/dev/null 2>&1
fi
$ESUDO kill -9 "$(pidof gptokeyb)" 2>/dev/null
pm_finish
