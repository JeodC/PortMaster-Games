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
source $controlfolder/tasksetter
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# Variables
GAMEDIR="/$directory/ports/grappledog"
GMLOADER="$HOME/gmloadernext"
GMLOADER_RUNTIME="$controlfolder/libs/gmloadernext.squashfs"
cd "$GAMEDIR"

# Log execution
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Mount gmloadernext runtime
GMLOADER="$HOME/gmloadernext"
GMLOADER_RUNTIME="$controlfolder/libs/gmloadernext.squashfs"
if [ -f "$GMLOADER_RUNTIME" ]; then
    $ESUDO mkdir -p "$GMLOADER"
    $ESUDO umount "$GMLOADER" 2>/dev/null || true
    $ESUDO mount "$GMLOADER_RUNTIME" "$GMLOADER"
else
    pm_message "This port requires the gmloadernext runtime. Please download it."
    pm_finish
    exit 1
fi

# Exports
export LD_LIBRARY_PATH="$GAMEDIR/libs:$GMLOADER/lib:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
export GMLOADER_LIB_PATH="$GMLOADER/lib"

# ---- BEGIN FUNCTIONS ---
thermal_setup() {
    for policy in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -d "$policy" ] && [ -f "$policy/scaling_max_freq" ] || continue
        orig=$(cat "$policy/scaling_max_freq") || continue
        target=$((orig * 8 / 10)) # Edit the first number here to boost or lower the cap
        $ESUDO sh -c "echo $target > '$policy/scaling_max_freq'" 2>/dev/null || true
        ORIG_MAX_FREQS="$ORIG_MAX_FREQS|$policy=$orig"
    done
}

thermal_restore() {
    OLDIFS=$IFS
    IFS='|'
    for entry in $ORIG_MAX_FREQS; do
        [ -z "$entry" ] && continue
        policy="${entry%=*}"
        orig="${entry#*=}"
        $ESUDO sh -c "echo $orig > '$policy/scaling_max_freq'" 2>/dev/null || true
    done
    IFS=$OLDIFS
}
# ---- END FUNCTIONS ---

# Check if we need to patch
if [ ! -f patchlog.txt ] || [ -f "$GAMEDIR/assets/data.win" ]; then
    if [ -f "$controlfolder/utils/patcher.txt" ]; then
        export PATCHER_FILE="$GAMEDIR/tools/patchscript"
        export PATCHER_GAME="$(basename "${0%.*}")"
        export PATCHER_TIME="a while"
        export controlfolder
        chmod +x "$PATCHER_FILE"
        source "$controlfolder/utils/patcher.txt"
        $ESUDO kill -9 $(pidof gptokeyb)
    else
        pm_message "This port requires the latest version of PortMaster."
        pm_finish
        exit 1
    fi
fi

# 2GB devices can trip thermal during spikes; cap CPU max freq 
# so the SoC stays under its passive cooling envelope.
ORIG_MAX_FREQS=""
if [ "${DEVICE_RAM:-0}" -le 2 ]; then thermal_setup; fi

# asoundrc fix for dArkOS
cfw_lower=$(echo "$CFW_NAME" | tr '[:upper:]' '[:lower:]')
RL_ASOUNDRC_APPLIED=0

case "$cfw_lower" in
    *darkos*)
        # dArkOS: install dmix asoundrc so ES and Rogue Legacy can share ALSA simultaneously.
        [ -f "$HOME/.asoundrc" ] && $ESUDO cp "$HOME/.asoundrc" "$HOME/.asoundrc.rl_bak"
        $ESUDO cp "$GAMEDIR/asoundrc" "$HOME/.asoundrc"
        RL_ASOUNDRC_APPLIED=1

        # dArkOS-specific SDL2 build fixes SDL_GL_LoadLibrary on this device's GPU stack.
        # Only used here - it's tuned to dArkOS's kernel/driver and can crash other CFWs.
        [ -f "$GAMEDIR/libs-darkos/libSDL2-2.0.so.0" ] && \
            export LD_LIBRARY_PATH="$GAMEDIR/libs-darkos:$LD_LIBRARY_PATH"

        export SDL_AUDIODRIVER=alsa
        echo "Using dArkOS-specific libSDL2 build + asoundrc + alsa"
        ;;
    *)
        echo "No CFW-specific audio fix needed for '$CFW_NAME' - using system default audio config"
        ;;
esac

# Run
$GPTOKEYB "gmloadernext.aarch64" -c "grappledog.gptk" &
pm_platform_helper "$GMLOADER/gmloadernext.aarch64" > /dev/null
$TASKSET "$GMLOADER/gmloadernext.aarch64" -c gmloader.json

# Cleanup
# Restore original ~/.asoundrc if needed
if [ "$RL_ASOUNDRC_APPLIED" = "1" ]; then
    if [ -f "$HOME/.asoundrc.rl_bak" ]; then
        $ESUDO mv "$HOME/.asoundrc.rl_bak" "$HOME/.asoundrc"
    else
        $ESUDO rm -f "$HOME/.asoundrc"
    fi
fi
if [ -n "$ORIG_MAX_FREQS" ]; then thermal_restore; fi
$ESUDO umount "$GMLOADER" 2>/dev/null || true
pm_finish
