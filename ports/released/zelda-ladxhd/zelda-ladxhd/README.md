## Installation
Place the original `Links Awakening DX HD v1.0.0.zip` file in the `zelda-ladxhd/data` folder. The port will automatically extract and patch the game to the latest [LADXHD-Updated](https://github.com/BigheadSMZ/Zelda-LA-DX-HD-Updated) release on first launch.

## Updates
The port tracks upstream's GitHub releases. When a newer release is detected on launch, the patcher re-runs from the preserved v1.0.0 base.

The patcher dialog asks whether to keep the update check enabled — pick **No** to freeze the port at its current upstream version. To re-enable later, delete `zelda-ladxhd/data/.update_check`.

If the device is offline at launch, the update check is skipped silently and the game runs as-is.

## Manual / offline patching
If your device has no internet connection, you can pre-stage the patcher files on a PC and the port will use them in place of downloading.

1. Find the latest upstream release tag at https://github.com/BigheadSMZ/Zelda-LA-DX-HD-Updated/releases/latest (e.g. `v1.8.0`).
    - Click on the tag label to be taken to the repository at that tag e.g. https://github.com/BigheadSMZ/Zelda-LA-DX-HD-Updated/tree/v1.8.0
2. Download `patches_linux_arm64.zip` from that tag and place it at `zelda-ladxhd/data/patches_linux_arm64.zip`:
   ```
   https://raw.githubusercontent.com/BigheadSMZ/Zelda-LA-DX-HD-Updated/<tag>/ladxhd_patcher_source_code/Resources/patches_linux_arm64.zip
   ```
3. Download `Functions.cs` from the same tag and place it at `zelda-ladxhd/data/Functions.cs`. This maps the upstream source files to their Linux outputs (including the game binary itself) and is **required** for an offline patch — with no internet to fetch it, the patcher will stop and report it missing rather than produce a broken install:
   ```
   https://raw.githubusercontent.com/BigheadSMZ/Zelda-LA-DX-HD-Updated/<tag>/ladxhd_patcher_source_code/Program/Functions.cs
   ```
4. (Optional) Download `achievements.zip` from the same tag and place it at `zelda-ladxhd/data/achievements.zip`. This holds the achievement icons; without it the achievements still work and show their text, but their icons will be missing:
   ```
   https://raw.githubusercontent.com/BigheadSMZ/Zelda-LA-DX-HD-Updated/<tag>/ladxhd_patcher_source_code/Resources/achievements.zip
   ```
5. Place your v1.0.0 zip in `zelda-ladxhd/data/` (same as a normal install).
6. Launch. The patcher uses the local files instead of downloading.

The version is stamped as `manual` after an offline patch, so the port will re-patch from upstream the next time the device comes online (unless you've turned off the update check).

## Notes
- Nintendo layout users should create a `swapabxy.txt` file in `zelda-ladxhd` and in game settings swap Confirm and Cancel for ui.
- Users with small display resolutions or odd aspect ratios can fiddle with the files in `zelda-ladxhd/data/Mods/LAHDMods` with a text editor to set ui scale to float overrides.

## Thanks
Nintendo -- The game  
BigheadSMZ -- The patches and mods to assist with compatibility as a retro handheld port  
