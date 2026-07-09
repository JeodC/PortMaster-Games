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
get_controls
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"

# Set variables
GAMEDIR="/$directory/ports/sonic.cd"

# CD and set permissions
cd $GAMEDIR
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1
$ESUDO chmod +x "$GAMEDIR/RSDKv3" 2>/dev/null

# Exports
export LD_LIBRARY_PATH="$GAMEDIR/libs":$LD_LIBRARY_PATH
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

get_res() {
    # RSDK default resolution
    BASE_WIDTH=424
    BASE_HEIGHT=240

    # Calculate integer scale factor for height
    SCALE=$(( DISPLAY_HEIGHT / BASE_HEIGHT ))

    # Calculate scaled width
    SCALED_WIDTH=$(( BASE_WIDTH * SCALE ))

    # If scaled width is too big for screen, reduce until it fits
    while [ $SCALED_WIDTH -gt $DISPLAY_WIDTH ]; do
        BASE_WIDTH=$(( BASE_WIDTH - 1 ))
        SCALED_WIDTH=$(( BASE_WIDTH * SCALE ))
    done

    # Final internal width is base width after adjustment
    WIDTH=$BASE_WIDTH

    # Update settings.ini
    if grep -q "^ScreenWidth=[0-9]\+" "$GAMEDIR/settings.ini"; then
        sed -i "s/^ScreenWidth=[0-9]\+/ScreenWidth=$WIDTH/" "$GAMEDIR/settings.ini"
    else
        echo "Possible invalid or missing settings.ini!"
    fi
}

# Adjust game resolution
get_res

# Extract Scripts and mod menu if needed
if [ -f "$GAMEDIR/Scripts.7z" ] && [ ! -d "$GAMEDIR/Scripts" ]; then
    echo "Extracting Scripts.7z..."
    if "$controlfolder/7zzs.${DEVICE_ARCH}" x -y -o"$GAMEDIR" "$GAMEDIR/Scripts.7z" >/dev/null 2>&1 \
       || 7z x -y -o"$GAMEDIR" "$GAMEDIR/Scripts.7z" >/dev/null 2>&1; then
        rm -f "$GAMEDIR/Scripts.7z"
    else
        echo "WARNING: failed to extract Scripts.7z; mod menu will not work."
    fi
fi

if [ -f "$GAMEDIR/mods.7z" ] && [ ! -d "$GAMEDIR/Scripts" ]; then
    echo "Extracting mods.7z..."
    if "$controlfolder/7zzs.${DEVICE_ARCH}" x -y -o"$GAMEDIR" "$GAMEDIR/mods.7z" >/dev/null 2>&1 \
       || 7z x -y -o"$GAMEDIR" "$GAMEDIR/mods.7z" >/dev/null 2>&1; then
        rm -f "$GAMEDIR/mods.7z"
    else
        echo "WARNING: failed to extract mods.7z; mod menu will not work."
    fi
fi

# Only run the patcher when there's actually Origins work to do. Mobile
# Data.rsdk users never need the patcher — engine loads their packed file
# directly.
needs_patching=false
[ -f "$GAMEDIR/SonicCDu.rsdk" ]  && needs_patching=true
[ -f "$GAMEDIR/SCD_music.awb" ]  && needs_patching=true
[ -f "$GAMEDIR/SCD_sfx.acb" ]    && needs_patching=true
[ -f "$GAMEDIR/HITE_sfx.acb" ]   && needs_patching=true

if [ "$needs_patching" = "true" ]; then
    if [ -f "$controlfolder/utils/patcher.txt" ]; then
        export PATCHER_FILE="$GAMEDIR/tools/patchscript"
        export PATCHER_GAME="$(basename "${0%.*}")"
        export PATCHER_TIME="2-10 minutes"
        export controlfolder
        export ESUDO
        export DEVICE_ARCH
        chmod +x "$PATCHER_FILE"
        source "$controlfolder/utils/patcher.txt"
        $ESUDO kill -9 $(pidof gptokeyb) 2>/dev/null
    else
        echo "This port requires the latest version of PortMaster."
    fi
elif [ ! -f "$GAMEDIR/Data.rsdk" ] && [ ! -f "$GAMEDIR/Data/Game/GameConfig.bin" ]; then
    echo "ERROR: no game data found in $GAMEDIR."
    echo "Drop either a mobile Data.rsdk, or the Origins bundle"
    echo "(SonicCDu.rsdk + SCD_music.acb/awb + SCD_sfx.acb + HITE_sfx.acb)."
    exit 1
fi

# GameType must match the data source:
#   Origins-extracted (loose Data/) -> GameType=1 (activates USE_ORIGINS
#                                       script branches, lets the v3 engine's
#                                       auto-detect find game.playMode)
#   mobile Data.rsdk                -> GameType=0
#
# If both sources are present (user dropped both), point DataFile away from
# the mobile rsdk so the loose Origins data wins.
GAMETYPE=0
DATAFILE=Data.rsdk
if [ -f "$GAMEDIR/Data/Game/GameConfig.bin" ]; then
    GAMETYPE=1
    [ -f "$GAMEDIR/Data.rsdk" ] && DATAFILE=Data.rsdk.disabled
fi

INI="$GAMEDIR/settings.ini"
if [ -f "$INI" ]; then
    if ! grep -q "^GameType=$GAMETYPE" "$INI"; then
        if grep -q "^GameType=" "$INI"; then
            sed -i "s/^GameType=[01]/GameType=$GAMETYPE/" "$INI"
        else
            sed -i "/^\[Game\]/a GameType=$GAMETYPE" "$INI"
        fi
        echo "settings.ini: GameType -> $GAMETYPE"
    fi
    if ! grep -q "^DataFile=$DATAFILE\$" "$INI"; then
        sed -i "s|^DataFile=.*|DataFile=$DATAFILE|" "$INI"
        echo "settings.ini: DataFile -> $DATAFILE"
    fi
fi

# Run the game
$GPTOKEYB "RSDKv3" -c "sonic.gptk" &
pm_platform_helper "RSDKv3" > /dev/null
"$GAMEDIR/RSDKv3"

# Cleanup
pm_finish