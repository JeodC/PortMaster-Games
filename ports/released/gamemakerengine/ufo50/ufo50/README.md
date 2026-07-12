# UFO 50
This is a wrapper and in-place scripts modification for vanilla UFO 50 that makes the game more manageable on retro handheld systems running linux arm64. If you are running android on a retro handheld system, you may be looking for the [unofficial android port](https://github.com/Skyline969/UFO50AndroidUnofficial) by Skyline969.

## Installation
This wrapper is compatible with all UFO 50 versions up to 1.9.5, the latest. Purchase the game on Steam and copy all the data to `ports/ufo50/assets`. On first run the game will be patched.

If you are updating a prepatched game, simply add your new `data.win` file to `assets` *in addition to any new data you want added*. This means you can add the `ext` folder for any language updates and the `Textures` folder.

## Performance Notes
This port features audio compression in an attempt to reduce memory usage. This is necessary in order for the port to run on the linux arm handhelds targeted. These handhelds are equipped with low-end rockchip or allwinner processors and usually 1-2GB of memory, alongside Mali blob drivers. Low processing power, low memory, and low VRAM are all major things to watch for when running ports on these devices. The following are known issues that are, again, **conditionally existent due to hardware and gmloader-next constraints**.

- Games that use large rooms will have lower fps (Ninpek, Velgress, Planet Zoldath, etc).

UFO 50 v1.7.0.1 implemented dynamic texture loading, which may alleviate slowdowns in these particular games further.

## RHH Patch Notes
For the more technically inclined, here are specific modifications made in order to make UFO 50 run smoothly on the targeted devices:

- [GMTools](https://github.com/cdeletre/gmtools) by Cyril Deletre to convert WAV to OGG and lower their bitrate
- [UndertaleModTool](https://github.com/UnderminersTeam/UndertaleModTool) to make some specific changes to the game
    - Remove/hide the scaling feature since the game always scales to the display on targeted devices, and enforce 1x scaling
    - Change the video settings menu to use `Stretch to Fit`, `Maintain Aspect Ratio`, and `Integer Scale` for display options
    - Remove/hide the scale options and the CRT shader options, since CRT shaders do not work on 1x scale
    
## Modding
The UFO 50 community has a number of mods that can work with the game. Most of them can be found on the [UFO 50 Community Discord](https://50games.fans) or [Gamebanana](https://gamebanana.com/mods/games/23000).

To use them, you will want to do the following:

#### ON A DESKTOP COMPUTER:
- Download [GMLoader](https://github.com/phil-macrocheira/GMLoader-UFO50) and extract it. Not to be confused with the GMLoader that runs GMS games.
- Download the mods you want and put them in the `my mods` folder.
- Start `UFO 50 Mod Installer.exe` and UNCHECK the `UFO50 Modding Framework` mod.
- Check the boxes for mods you want to merge into your game.
- Click the `Install Mods` button. Wait for confirmation your mods were installed.

#### ON YOUR RETRO HANDHELD DEVICE
- Copy all the game data to `ufo50/assets`.
- Run the port. The patcher gui will appear and begin processing your modifications.

#### IF A MODDED UFO 50 DOES NOT WORK AS EXPECTED
- The modified gml scripts used for this Retro Handheld port are in `tools/gml`. These replace the existing gml scripts, so if any mods are dependent on them, there will be conflicts.

## Runtimes

This port requires the following:

- [gmtoolkit.aarch64](https://github.com/JeodC/gmtoolkit/releases/latest) placed in the `PortMaster/` folder.
- [gmloadernext.squashfs](https://github.com/JeodC/RHH-Ports/raw/main/runtimes/gmloadernext.squashfs) placed in the `PortMaster/libs/` folder.

[Pharos](https://github.com/JeodC/RHH-Ports/releases/download/ports-latest/pharos.zip) will fetch these automatically when installing the port. Otherwise download them manually and add them to the correct folders.

## Thanks
Mossmouth -- The absolutely amazing game  
JohnnyOnFlame -- GMLoader-Next and TextureRepacker via UTMT  
Cyril aka kotzebuedog -- GMTools audio patcher  
mavica -- Display patch  
phil_macrocheira -- Code diff files when the game patches (makes it easy to update port)  
Testers & Devs from the PortMaster Discord