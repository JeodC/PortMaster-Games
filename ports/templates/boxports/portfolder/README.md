## Installation

This port runs the native Linux build of the game via Box64 (with Box32) — a
single aarch64 emulator that handles both **x86_64 and 32-bit x86** binaries.
Wine is not involved, and no armhf libraries are needed. Box64 ships in the
shared `box.squashfs` runtime, not in the port.

Copy your Linux game files into `ports/portfolder/data/`. Saves live in
`ports/portfolder/saves/`. If a game needs extra native libraries Box64 can't
wrap, drop the aarch64 copies in `ports/portfolder/libs.aarch64/` — never inside
the shared runtime.

If you own the Steam version, you can usually grab the Linux depot via Steam's
console with `download_depot <appid> <depotid>`.

## Default Gameplay Controls
| Button            | Action |
|--                 |--|
| START             | |
| SELECT            | |
| D-PAD / JOYSTICK  | |
| A                 | |
| B                 | |
| X                 | |
| Y                 | |
| L1                | |
| R1                | |
| L2                | |
| R2                | |

## Thanks

ptitSeb -- Box64
