## Installation
You need a copy of [Air Standard Edition](https://vndb.org/r87). Install the `rlvm` runtime and copy the game files to `ports/air/gamedata`.

## Notes
Air Standard Edition has an [English Patch](https://winter-confetti.blogspot.com/2014/04/air-standard-edition-2005-english-patch.html). Other versions and patches are untested. 

This port is marked experimental because we can't save and load games due to the inability to display the right-click context menu.

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
