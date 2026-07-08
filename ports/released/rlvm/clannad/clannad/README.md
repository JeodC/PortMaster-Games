## Installation
You can use a few different versions of Clannad with this port:

- [Clannad Regular Edition](https://vndb.org/r303) / [Full Voice](https://vndb.org/r13)
- [Clannad HD](https://store.steampowered.com/app/324160)

The easiest by far is Clannad HD via Steam, but the earlier versions should work fine if you have them. Install the `rlvm` runtime and add your game assets to `ports/clannad/gamedata`. File structure below:

```
Clannad/gamedata
├───bgm
├───dat
├───g00
├───gan
├───koe
├───mov (not used atm but might be usable in the future; removing saves 473MB space)
└───wav
└───Gameexe.ini
└───Seen.txt
```

This is a big port!! The Clannad HD Steam edition is roughly 5GB total of gamedata!

## Notes
There is a graphical bug where the textures behind the textbox are sliced. To fix this, open the menu, go to configuration, and in the upper right, tick the box for `Transparency Color` for window background.

## Default Gameplay Controls
| Button | Action |
|--|--|
|Select|Back|
|Start|Start|
|A|Accept|
|B|Cancel / Open Menu|
|L1|Scroll back dialog|
|R1|Scroll forward dialog|
|L2|Fast forward dialog|
|D-Pad / Sticks|Move cursor|


## Runtimes

This port requires the following runtimes in `PortMaster/libs`:

- **RLVM** — [rlvm-sdl2.squashfs](https://github.com/JeodC/RHH-Ports/raw/main/runtimes/rlvm-sdl2.squashfs)

[Pharos](https://github.com/JeodC/RHH-Ports/releases/download/ports-latest/pharos.zip) will fetch these automatically when installing the port. Otherwise download them manually from the [runtimes folder](https://github.com/JeodC/RHH-Ports/tree/main/runtimes) and drop them in `PortMaster/libs`.

## Thanks
Kloptops - Original port  
eglaysher - Rlvm original  
a1batross - Rlvm SDL2 fork  
Testers and Devs from the PortMaster Discord  
