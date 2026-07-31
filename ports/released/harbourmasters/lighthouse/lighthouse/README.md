## Installation
You need to provide your own rom. The supported roms are:

| Version | SHA-1 |
|---|---|
| USA Rev 0 | 1FE1632098865F639E22C11B9A81EE8F29C75D7A |
| USA Rev 1 | DED6EE166E740AD1BC810FD678A84B48E245AB80 |
| PAL | BB359A75941DF74BF7290212C89FBC6E2C5601FE |
| JP | 90726D7E7CD5BF6CDFD38F45C9ACBF4D45BD9FD8 |

You can verify you have dumped a supported copy of the game by using the SHA-1 File Checksum Online at https://www.romhacking.net/hash/.

Legally obtain your rom and place it in `ports/lighthouse/baseroms`, then start the port. It must be in **big-endian `.z64` format** — `.n64` and `.v64` are not detected. Use https://hack64.net/tools/swapper.php to convert if needed. Lighthouse will offer to process any roms it finds. If none are found you will instead be prompted to pick your rom with the built-in file browser. Either way, Torch generates a `bk.o2r` in place. This takes a few minutes, on the first boot only.

Logs are recorded automatically as `ports/lighthouse/log.txt`. Please provide a log if you report an issue. HarbourMasters is not affiliated with PortMaster or RHH-Ports and this distribution is not officially supported by them. *Please report an issue to the RHH-Ports repository before going to HarbourMasters!*

## Additional Features
Lighthouse features a few extended features:

- You may choose from three gamepad presets: `Retro`, for N64, `Modern`, for Xbox Live Arcade, and `Pocket`, for Super Pocket (D-Pad friendly). After choosing a preset, you can customize your input as usual.
- If you have multiple regions of Banjo-Kazooie, you can generate slim language packs from them in the imgui Settings -> General menu.
- Romhacks are supported! In the Settings -> Romhack Menu, you can select a romhack to convert to o2r. It will be diffed against Banjo-Kazooie US v1.0 hashes and only the differing assets will be extracted.
- Mods are supported for the base game as usual, but romhacks can also accept specific mods! Mods specific to a romhack go in `mods/<romhack>/`, while mods that can be shared with all romhacks go in `mods/~shared/`.
- Lighthouse supports online multiplayer with Anchor! You can modify your `name` and `room id` in `Lighthouse.sh`, and then connect to Anchor from the imgui `Network` menu. In the global public room, you can see other players as you play through independent save files. If you create your own room, you can play cooperatively.

## Menu Navigation
Lighthouse has built-in controller navigation for the imgui menu. Press `SELECT` to open the menu and use the `D-PAD` to choose a submenu, then press `A` to switch focus to it. Press `B` to back out of a submenu.

There is also a `lighthouse.gptk` file you can use to change which button emulates F1, the keyboard shortcut for the menu (default is L3). Some devices have a special button called `guide` that makes for a good F1 mapping.

## Credits
- Banjo-Kazooie made by Rare
- Source port by HarbourMasters
- Linux SBC build by Jeod

Third-party licenses for the components bundled with this port are in `licenses/`.
