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
GAMEDIR="/$directory/ports/sonictimetwisted"

# CD and set permissions
cd $GAMEDIR
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

PORTFILE="$GAMEDIR/sonictimetwisted.port"
if [ ! -f "$PORTFILE" ] && [ -f "$PORTFILE.part.001" ]; then
    pm_message "First run: assembling game data (~134 MB), please wait..."
    if cat "$PORTFILE".part.* > "$PORTFILE"; then
        rm -f "$PORTFILE".part.*
    else
        rm -f "$PORTFILE"
        pm_message "Could not assemble game data. Check for free space on your card."
        pm_finish
        exit 1
    fi
fi

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

export GMLOADER_LIB_PATH="$GMLOADER/lib"

# Exports
export LD_LIBRARY_PATH="$GMLOADER/lib:$GAMEDIR/lib:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"


# Assign gptokeyb and load the game
$GPTOKEYB "gmloadernext.aarch64" -c "sonic.gptk" &
pm_platform_helper "$GMLOADER/gmloadernext.aarch64" >/dev/null
"$GMLOADER/gmloadernext.aarch64" -c gmloader.json

# Cleanup
# Unmount gmloadernext runtime
$ESUDO umount "$GMLOADER" 2>/dev/null || true

pm_finish
