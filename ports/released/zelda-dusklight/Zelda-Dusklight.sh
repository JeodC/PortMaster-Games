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

# Set variables
GAMEDIR="/$directory/ports/zelda-dusklight"
GAME="$GAMEDIR/dusklight"

# CD and set log
cd "$GAMEDIR"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1
$ESUDO chmod +x "$GAME"

# Create directories
mkdir -p "$GAMEDIR/config"

# Exports
export XDG_DATA_HOME="$GAMEDIR/config"
export LD_LIBRARY_PATH="$GAMEDIR/libs:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# Locate the disc image directly in the port folder
DVD=""
for ext in ciso iso gcm rvz nkit.iso; do
    for f in "$GAMEDIR"/*."$ext"; do
        [ -f "$f" ] && DVD="$f" && break 2
    done
done

if [ -z "$DVD" ]; then
    pm_message "No Twilight Princess disc image found in ports/zelda-dusklight."
    sleep 5
    pm_finish
    exit 1
fi

# Patch the disc image path into the config
CONFIG_DIR="$GAMEDIR/config/TwilitRealm/Dusklight"
[ -d "$CONFIG_DIR" ] || CONFIG_DIR="$GAMEDIR/config/TwilitRealm/Dusk"
CONFIG="$CONFIG_DIR/config.json"
CURRENT=$(sed -n 's/.*"backend\.isoPath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" 2>/dev/null)
if [ -z "$CURRENT" ] || [ ! -f "$CURRENT" ]; then
    DVD_ESC=$(printf '%s' "$DVD" | sed 's/[\\&|]/\\&/g')
    sed -i "s|\"backend\.isoPath\": \"[^\"]*\"|\"backend.isoPath\": \"$DVD_ESC\"|" "$CONFIG"
fi

# Run the game
$GPTOKEYB "dusklight" -c "zelda-dusklight.gptk" &
pm_platform_helper "$GAME" >/dev/null
"$GAME" --backend vulkan

# Cleanup
rm -rf "$CONFIG_DIR/logs/"*
pm_finish
