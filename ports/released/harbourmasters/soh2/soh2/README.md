## Information
2Ship2Harkinian binaries were built from GitHub Actions at the [HarbourMasters Autobuild Factory](https://github.com/JeodC/hm64-builder).

## Installation
You must generate your `mm.o2r` file with a rom that has one of the following SHAs:

```
d6133ace5afaa0882cf214cf88daba39e266c078 - N64 US
9743aa026e9269b339eb0e3044cd5830a440c1fd - GC US
```

You can verify your rom at https://2ship.equipment.

The rom must be uncompressed (not inside a `.zip` or `.7z`) and keep a `.z64`, `.n64` or `.v64` extension. Legally obtain your rom and place it in `ports/soh2`, then start the port. 2Ship2Harkinian finds the rom on its own and walks you through generating `mm.o2r` on the first launch.

Texture pack files can be added to the `ports/soh2/mods` folder.

Logs are recorded automatically as `ports/soh2/log.txt`. Please provide a log if you report an issue. HarbourMasters is not affiliated with PortMaster or RHH-Ports and this distribution is not officially supported by them. *Please report an issue to the RHH-Ports repository before going to HarbourMasters!*

## Graphics Adjustments
You can open `2ship2harkinan.json` in a text editor and modify the values as you wish. If you mess up the syntax, the game will regenerate this file and your settings will be reverted to default. Please create a backup before modification.

## Menu Navigation
2Ship2Harkinian has built-in controller navigation for the imgui menu. Press `SELECT` to open the menu and use the `D-PAD` to choose a submenu, then press `A` to switch focus to it. Press `B` to back out of a submenu.

## Default Gameplay Controls
The port uses SDL controller mapping and controls can be remapped from the menu bar. For devices without a right analog stick, the gptk file allows for the `HOTKEY + ABXY` button combo to use the C-Buttons.

## Suggested Mods
You can find mods at https://gamebanana.com/games/20371.

## Thanks
- Nintendo for the game
- HarbourMasters for the native pc port
- AkerHasReawakened for the cover art




