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
GAMEDIR="/$directory/ports/sonic.1"

# CD and set permissions
cd $GAMEDIR
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1
$ESUDO chmod +x "$GAMEDIR/RSDKv4" 2>/dev/null
$ESUDO chmod +x "$GAMEDIR/sonicforever" 2>/dev/null

# Exports
export LD_LIBRARY_PATH="/usr/lib:$GAMEDIR/libs":$LD_LIBRARY_PATH
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

# Only run the patcher when there's actually Origins work to do
needs_patching=false
[ -f "$GAMEDIR/Sonic1u.rsdk" ]   && needs_patching=true
[ -f "$GAMEDIR/STH1_music.awb" ] && needs_patching=true
[ -f "$GAMEDIR/STH1_sfx.acb" ]   && needs_patching=true
[ -f "$GAMEDIR/HITE_sfx.acb" ]   && needs_patching=true

if [ "$needs_patching" = "true" ]; then
    if [ -f "$controlfolder/utils/patcher.txt" ]; then
        export PATCHER_FILE="$GAMEDIR/tools/patchscript"
        export PATCHER_GAME="$(basename "${0%.*}")"
        export PATCHER_TIME="1-5 minutes"
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
    echo "(Sonic1u.rsdk + STH1_music.acb/awb + STH1_sfx.acb + HITE_sfx.acb)."
    exit 1
fi

# Binary selection:
#   sonicforever — spec58's custom RSDKv4 build for the Sonic Forever mod.
#                  Reads either a mobile Data.rsdk or a loose Origins-
#                  extracted Data/ tree. Selected when the Forever mod
#                  flag is on.
#   RSDKv4       — everything else (Forever flag off).
#
# GameType must match the chosen binary + data:
#   Forever + mobile       -> GameType=0 (Standalone scripts), DataFile=Data.rsdk
#   RSDKv4  + Origins data -> GameType=1 (activates USE_ORIGINS branches),
#                             DataFile=Data.rsdk.disabled so the engine ignores
#                             any leftover mobile rsdk and uses the loose Data/.
#   RSDKv4  + mobile only  -> GameType=0, DataFile=Data.rsdk
# Users with BOTH data sources toggle behavior via the Forever mod flag,
# so we re-assert these on every launch.
GAME=RSDKv4
GAMETYPE=0
DATAFILE=Data.rsdk
MENU_RECREATION=true   # default: on
if [ -f "$GAMEDIR/sonicforever" ] \
   && grep -q "^SonicForeverMod=true" "$GAMEDIR/mods/modconfig.ini" 2>/dev/null; then
    GAME=sonicforever
    GAMETYPE=0
    DATAFILE=Data.rsdk
    # Forever replaces the menu itself; don't also run Menu Recreation.
    MENU_RECREATION=false
elif [ -f "$GAMEDIR/Data/Game/GameConfig.bin" ]; then
    # Origins data extracted (loose Data/ present) -> Origins scripts.
    # If Data.rsdk is also present (e.g. user dropped both), point the
    # engine away from it so the loose Origins data is authoritative.
    GAMETYPE=1
    [ -f "$GAMEDIR/Data.rsdk" ] && DATAFILE=Data.rsdk.disabled
fi

# Mutex the mod sets. Menu Recreation and Sonic Forever both provide a menu
# system — running them together confuses the engine's start-menu flow.
# Forever strips `Menu Recreation=...` from modconfig.ini entirely when it
# starts up, so we can't just sed-replace — we also have to re-insert the
# line under [mods] if it's gone.
MODCFG="$GAMEDIR/mods/modconfig.ini"
if [ -f "$MODCFG" ]; then
    want="Menu Recreation=$MENU_RECREATION"
    if grep -q "^Menu Recreation=" "$MODCFG"; then
        sed -i "s/^Menu Recreation=.*/$want/" "$MODCFG"
    elif grep -q "^\[mods\]" "$MODCFG"; then
        sed -i "/^\[mods\]/a $want" "$MODCFG"
    else
        # No [mods] section at all — prepend one.
        printf '[mods]\n%s\n' "$want" >> "$MODCFG"
    fi
fi

# Sync settings.ini to match. The Forever binary strips the GameType line
# entirely on startup, so we have to handle both "wrong value" (sed
# replace) and "line missing" (re-insert under [Game]).
INI="$GAMEDIR/settings.ini"
if [ -f "$INI" ]; then
    if ! grep -q "^GameType=$GAMETYPE" "$INI"; then
        if grep -q "^GameType=" "$INI"; then
            sed -i "s/^GameType=[01]/GameType=$GAMETYPE/" "$INI"
        else
            sed -i "/^\[Game\]/a GameType=$GAMETYPE" "$INI"
        fi
        echo "settings.ini: GameType -> $GAMETYPE ($GAME)"
    fi
    if ! grep -q "^DataFile=$DATAFILE\$" "$INI"; then
        sed -i "s|^DataFile=.*|DataFile=$DATAFILE|" "$INI"
        echo "settings.ini: DataFile -> $DATAFILE"
    fi
fi

# Run the game
$GPTOKEYB "$GAME" -c "sonic.gptk" &
pm_platform_helper "$GAME" >/dev/null
"$GAMEDIR/$GAME"

# Cleanup
pm_finish
