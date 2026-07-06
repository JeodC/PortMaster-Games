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
GAMEDIR="/$directory/ports/marvelcosmicinvasion"

# CD and set logging
cd "$GAMEDIR/gamedata"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Mono runtime
MONODIR="$HOME/mono"
MONOFILE="$controlfolder/libs/mono-6.12.0.122-aarch64.squashfs"
$ESUDO mkdir -p "$MONODIR"
$ESUDO umount "$MONODIR" 2>/dev/null || true
$ESUDO mount "$MONOFILE" "$MONODIR"
MONO="$MONODIR/bin/mono"
if [ ! -x "$MONO" ]; then
    pm_message "Failed to mount the Mono runtime. Cannot continue."
    exit 1
fi
echo "Using $("$MONO" --version | head -1)"

# Save directory
mkdir -p "$HOME/.local/share/Tribute Games"
$ESUDO rm -rf "$HOME/.local/share/Tribute Games/MARVELCosmicInvasion"
mkdir -p "$GAMEDIR/savedata"
ln -sfv "$GAMEDIR/savedata" "$HOME/.local/share/Tribute Games/MARVELCosmicInvasion"

# Strip bundled Windows deps
rm -f System*.dll mscorlib.dll Mono.*.dll WindowsBase.dll
# Harvest the game's own FNA.dll for the port (we do not distribute it)
[ -f "$GAMEDIR/dlls/FNA.dll" ] || cp -f FNA.dll "$GAMEDIR/dlls/FNA.dll" 2>/dev/null
rm -f FNA.dll FNA.dll.config
rm -f SDL2.dll SDL3.dll FNA3D.dll FAudio.dll MojoShader.dll fmod.dll fmodstudio.dll

# Friendly ownership nudge
if [ -f steam_api64.dll ] && ! grep -q "Valve" steam_api64.dll; then
    pm_message "This doesn't look like a genuine copy. Please support Tribute Games by buying MARVEL Cosmic Invasion on Steam."
fi
rm -f steam_api64.dll EOSSDK-Win64-Shipping.dll libtheorafile.dll

# Copy supplied files to gamedata
cp -f "$GAMEDIR/ParisEngine.dll.config" "$GAMEDIR/gamedata/ParisEngine.dll.config"
cp -f "$GAMEDIR/NBug.config" "$GAMEDIR/gamedata/NBug.config"

# Environment
export MONO_IOMAP=all
export XDG_DATA_HOME="$HOME/.local/share"
export MONO_PATH="$GAMEDIR/dlls:$GAMEDIR/gamedata:$GAMEDIR/monomod"
export LD_LIBRARY_PATH="$GAMEDIR/libs:$MONODIR/lib:/usr/lib:$LD_LIBRARY_PATH"
export PATH="$MONODIR/bin:$PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
export MONO_LOG_LEVEL=warning
export FNA3D_FORCE_DRIVER="OpenGL"
export FNA3D_OPENGL_FORCE_ES3=1

# Check if we need to patch the game
if [ ! -f "$GAMEDIR/patchlog.txt" ] || [ ! -f "$GAMEDIR/gamedata/.mci_patched" ]; then
    if [ -f "$controlfolder/utils/patcher.txt" ]; then
        export PATCHER_FILE="$GAMEDIR/tools/patchscript"
        # Ask about the intro re-encode once, only while it is still undecided.
        [ -f "$GAMEDIR/gamedata/.intro_done" ] || export PATCHER_QUESTIONS="$GAMEDIR/tools/questions.lua"
        export PATCHER_GAME="$(basename "${0%.*}")"
        export PATCHER_TIME="5 to 40 minutes depending on device"
        export MONODIR MONO
        export controlfolder ESUDO DEVICE_ARCH
        source "$controlfolder/utils/patcher.txt"
        $ESUDO kill -9 $(pidof gptokeyb)
    else
        echo "This port requires the latest version of PortMaster."
    fi
fi

# Bail if the patch failed
if [ ! -f "$GAMEDIR/gamedata/.mci_patched" ]; then
    $ESUDO umount "$MONODIR" 2>/dev/null
    pm_finish
    exit 1
fi

# Display loading splash
[ "$CFW_NAME" == "muOS" ] && $ESUDO "$GAMEDIR/tools/splash" "$GAMEDIR/splash.png" 1 
$ESUDO "$GAMEDIR/tools/splash" "$GAMEDIR/splash.png" 80000 &

# Face-button layout
if [ -f "$GAMEDIR/swapabxy.txt" ]; then
    chmod +x "$GAMEDIR/tools/swapabxy.py"
    if [ -n "$SDL_GAMECONTROLLERCONFIG_FILE" ] && [ -f "$SDL_GAMECONTROLLERCONFIG_FILE" ]; then
        cat "$SDL_GAMECONTROLLERCONFIG_FILE" | "$GAMEDIR/tools/swapabxy.py" > "$GAMEDIR/gamecontrollerdb_swapped.txt"
        export SDL_GAMECONTROLLERCONFIG_FILE="$GAMEDIR/gamecontrollerdb_swapped.txt"
    fi
    if [ -n "$SDL_GAMECONTROLLERCONFIG" ]; then
        export SDL_GAMECONTROLLERCONFIG="`echo "$SDL_GAMECONTROLLERCONFIG" | "$GAMEDIR/tools/swapabxy.py"`"
    fi
fi

# Audio enumeration fallback
MCI_ASOUNDRC=""
if command -v aplay >/dev/null 2>&1 \
   && ! aplay -L 2>/dev/null | grep -qx default \
   && pidof pipewire >/dev/null 2>&1 \
   && [ ! -e "$HOME/.asoundrc" ]; then
    cp -f "$GAMEDIR/tools/asound-default.conf" "$HOME/.asoundrc" && MCI_ASOUNDRC="1"
    echo "Audio: exposed a hinted pipewire 'default' via ~/.asoundrc"
fi

# Run it
$GPTOKEYB "mono" -c "$GAMEDIR/mci.gptk" &
pm_platform_helper "$MONO" >/dev/null
$TASKSET "$MONO" --ffast-math -O=all "Game.exe"

# Cleanup
[ "$MCI_ASOUNDRC" = "1" ] && rm -f "$HOME/.asoundrc"
$ESUDO umount "$MONODIR" 2>/dev/null
pm_finish
