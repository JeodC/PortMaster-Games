## Installation
This port uses the Steam release of Clannad Side Stories:

- [Clannad Side Stories (Steam)](https://store.steampowered.com/app/420100/CLANNAD_Side_Stories/)

Install the `rlvm` runtime and add your game assets to `ports/clannadss/gamedata`. File structure below:

```
clannadss/gamedata
├───bgm
├───g00
├───koe
├───wav
└───Gameexe.ini
└───Seen.txt
```

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

## Notes

Side Stories is an auto-text game, unlike other visual key novels. It is also experimental and may have issues.


## Runtimes

This port requires the following runtimes in `PortMaster/libs`:

- **RLVM** — [rlvm-sdl2.squashfs](https://github.com/JeodC/RHH-Ports/raw/main/runtimes/rlvm-sdl2.squashfs)

[Pharos](https://github.com/JeodC/RHH-Ports/releases/download/ports-latest/pharos.zip) will fetch these automatically when installing the port. Otherwise download them manually from the [runtimes folder](https://github.com/JeodC/RHH-Ports/tree/main/runtimes) and drop them in `PortMaster/libs`.

## Thanks
eglaysher - Rlvm original  
a1batross - Rlvm SDL2 fork  
Testers and Devs from the PortMaster Discord
