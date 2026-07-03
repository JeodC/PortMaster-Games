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
GAMEDIR="/$directory/ports/digitaltamers2"

# CD and set logging
cd $GAMEDIR
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
export GMLOADER_LIB_PATH="$GMLOADER/lib"
export LD_LIBRARY_PATH="$GMLOADER/lib:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# Check if we need to patch the game
if [ ! -f patchlog.txt ] || ls "$GAMEDIR/assets/"*.apk >/dev/null 2>&1; then
    if [ -f "$controlfolder/utils/patcher.txt" ]; then
        export PATCHER_FILE="$GAMEDIR/tools/patchscript"
        export PATCHER_GAME="$(basename "${0%.*}")"
        export PATCHER_TIME="5 to 15 minutes"
        export controlfolder
        export ESUDO
        export DEVICE_ARCH
        chmod +x "$PATCHER_FILE"
        source "$controlfolder/utils/patcher.txt"
        $ESUDO kill -9 $(pidof gptokeyb)
    else
        echo "This port requires the latest version of PortMaster."
    fi
fi

# On sway compositors (e.g. ROCKNIX) hide the OS mouse cursor
HID_CURSOR=0
if command -v swaymsg >/dev/null 2>&1 && swaymsg -t get_version >/dev/null 2>&1; then
    CURSOR_THEME_DIR="$HOME/.icons/hidden/cursors"
    mkdir -p "$CURSOR_THEME_DIR"
    for _c in left_ptr default arrow top_left_arrow pointer left_ptr_watch; do
        cp -f "$GAMEDIR/tools/hidden_cursor" "$CURSOR_THEME_DIR/$_c" 2>/dev/null
    done
    printf '[Icon Theme]\nName=hidden\n' > "$HOME/.icons/hidden/index.theme"
    swaymsg seat '*' xcursor_theme hidden 24 >/dev/null 2>&1 && HID_CURSOR=1
fi

# Assign gptokeyb and load the game
$GPTOKEYB "gmloadernext.aarch64" -c "dt2.gptk" &
pm_platform_helper "$GMLOADER/gmloadernext.aarch64" >/dev/null
"$GMLOADER/gmloadernext.aarch64" -c gmloader.json

# Cleanup
[ "$HID_CURSOR" = "1" ] && swaymsg seat '*' xcursor_theme default 24 >/dev/null 2>&1
$ESUDO umount "$GMLOADER" 2>/dev/null || true
pm_finish
