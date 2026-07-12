## Installation
Add your game data from your Steam or Itch.io installation to `ports/iosas/assets`. First-time run will handle sorting data.

## Default Gameplay Controls
| Button | Action |
|--|--|
|START|Menus|
|SELECT|Map|
|D-PAD / Analog|Move|
|L1|Undo|
|R1|Reset room|

## Config
The patch enables `saves/config.ini`. The god-mandala effect (which bogs down the CPU in certain rooms) now throttles its own redraw rate automatically, so there is no frameskip to tune. The one remaining option is `IdolSFX`: set `IdolSFX=0` to turn the effect off entirely for no stuttering at all. The patcher picks a sensible default based on your device's CPU.

## Importing / Exporting Save Data
Steam saves are located at `\AppData\Local\IslesOfSeaAndSky` on Windows. Copy `save_v1_000.dat` or similar to `ports/iosas/saves` to use it. To export save data to your Steam or Itch.io install, do the reverse.

## Runtimes

This port requires the following:

- [gmtoolkit.aarch64](https://github.com/JeodC/gmtoolkit/releases/latest) placed in the `PortMaster/` folder.
- [gmloadernext.squashfs](https://github.com/JeodC/RHH-Ports/raw/main/runtimes/gmloadernext.squashfs) placed in the `PortMaster/libs/` folder.

[Pharos](https://github.com/JeodC/RHH-Ports/releases/download/ports-latest/pharos.zip) will fetch these automatically when installing the port. Otherwise download them manually and add them to the correct folders.

## Thanks
Cicada Games -- The game and [press kit materials](https://islesofseaandsky.com/press-kit) used to create the splash screen  
Cyril "kotzebuedog" Delétré -- The phenomenal audio patch that makes this port possible  
JohnnyOnFlame -- GMLoaderNext  
Jeod, Ganimoth -- Port creator and maintainer  
Testers and Devs from the PortMaster Discord  
