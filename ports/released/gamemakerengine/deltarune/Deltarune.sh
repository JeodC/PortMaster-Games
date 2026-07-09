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
GAMEDIR="/$directory/ports/deltarune"

# CD and set log
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
export LD_LIBRARY_PATH="$GMLOADER/lib:$GAMEDIR/libs:$LD_LIBRARY_PATH"
export GMLOADER_LIB_PATH="$GMLOADER/lib"

# Pretend we're on SteamDeck, some game code needs this
export SteamDeck=1

check_patch() {
    # Check for items in install folder (excluding base.port), data.win, or other subfolders
    install_items=$(find "$GAMEDIR/assets/install" -maxdepth 1 -mindepth 1 -not -name "base.port")
    has_data_win=$( [ -f "$GAMEDIR/assets/data.win" ] && echo true || echo false )
    has_other_subdir=$(find "$GAMEDIR/assets" -mindepth 1 -maxdepth 1 -type d ! -name "install" | head -n 1)

    # If patchlog.txt is missing, or we have installable items, data.win, or other subdirs
    if [ ! -f "$GAMEDIR/patchlog.txt" ] || [ -n "$install_items" ] || [ "$has_data_win" = true ] || [ -n "$has_other_subdir" ]; then
        if [ -f "$controlfolder/utils/patcher.txt" ]; then
            set -o pipefail
            export PATCHER_FILE="$GAMEDIR/tools/patchscript"
            export PATCHER_GAME="$(basename "${0%.*}")"
            export PATCHER_TIME="a while"
            export PATCHER_QUESTIONS="$GAMEDIR/tools/questions.lua"
            export controlfolder ESUDO DEVICE_ARCH DEVICE_RAM DISPLAY_WIDTH DISPLAY_HEIGHT
            chmod +x "$PATCHER_FILE"
            source "$controlfolder/utils/patcher.txt"
        else
            pm_message "This port requires the latest version of PortMaster."
            pm_finish
            exit 1
        fi
    fi
}

# Check if we need to patch the game
check_patch

# Assign gptokeyb and load the game
$GPTOKEYB "gmloadernext.aarch64" &
pm_platform_helper "$GMLOADER/gmloadernext.aarch64" >/dev/null
"$GMLOADER/gmloadernext.aarch64" -c gmloader.json

# Cleanup
$ESUDO umount "$GMLOADER" 2>/dev/null || true
pm_finish
