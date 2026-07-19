## Installation

Grab the Linux depot via Steam's console and copy the downloaded files into `ports/fieldsofmistria/data/`. If you have a save file, you can copy it to `ports/fieldsofmistria/saves/`.

## Requirements

This is a heavy port and is only expected to run on high-end devices:

- **CPU**: a fast 64-bit ARM SoC that runs x86_64 games well under Box64 (Snapdragon 8-series, RK3588, or similar). RK3326/RK3566-class chips are not supported.
- **GPU**: OpenGL 4.x is required. The game's engine requests an OpenGL 4.6 Core context, which it obtains through Vulkan (zink) or native desktop GL. Devices limited to OpenGL ES / gl4es cannot run it.
- **RAM**: the game loads ~500 MB of assets and is memory-hungry; 8 GB is recommended, and 4 GB devices may run out of memory.
- **Storage**: roughly 525 MB for the game files.
- **First boot is slow**: the engine compiles all of its scripts on startup (30+ seconds).

## Editing your name

If you start a new game, you will have to approve the default player and farm names due to lack of a keyboard. You can modify your save immediately after starting the game if desired:

- Download [vaultc](https://github.com/NPC-Studio/vaultc) and put it in a temporary directory.
- Copy your .sav file to the same directory
- In terminal type `./vaultc unpack <save filename> out`
- Edit `header.json:5`, `player.json:3070`, and `gamedata.json:377` for player name
- Edit `header.json:4` and `player.json:238` for farm name
- In terminal type `./vaultc pack out <save filename>`
- Copy your rebuilt .sav file back to the port

## Thanks
- NPC Studio: Fields of Mistria
- ptitSeb: Box64
