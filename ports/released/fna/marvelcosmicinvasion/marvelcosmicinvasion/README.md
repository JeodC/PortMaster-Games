# Installation

Buy MARVEL Cosmic Invasion on [Steam](https://store.steampowered.com/app/2753970/) and copy the **entire** game folder (Windows install) into `marvelcosmicinvasion/gamedata/`.

## Notes

DLC is packaged with the base game and is enabled with an entitlement check. Therefore, this port **cannot** distinguish between game data with dlc purchased vs not purchased. In accordance, DLC is left disabled.

This port has been tested from first run patching to playable runtime on a H700 device with a Mali-G31 GPU. As always with ports, for the best experience, play with a stronger device.

## Thanks

**MARVEL Cosmic Invasion** is developed by **Tribute Games**. This port only wraps their game. Please buy it on Steam to support them.

Port by Jeod. The engine patches, launcher, patch scripts, and the bundled FNA3D/FAudio/ffmpeg builds are RHH work. Everything below is not:

- **JohnnyonFlame**: this port is possible because of Johnny's [FNAPatches](https://github.com/JohnnyonFlame/FNAPatches) and TMNT: Shredder's Revenge groundwork.
- **MonoMod** (0x0ade & contributors) and **Mono.Cecil** (Jb Evain).
- **Ethan "flibitijibibo" Lee**: FNA, FNA3D, FAudio, and Theorafile, the stack that makes the game run at all. The bundled `libFNA3D.so.0` is an RHH-modified build and is not an official FNA3D binary.
- **FFmpeg** and the **Xiph.Org** codecs (libtheora, libogg, libvorbis): the bundled `tools/ffmpeg` is an RHH slim LGPL build that links them to re-encode the intro video.
- **Arm**: the astc-encoder library, embedded in the bundled `libastcUtil.so`.
- **DotNetZip** contributors.
- **Firelight Technologies Pty Ltd**: FMOD Studio audio engine, bundled under its licence terms.
- **K-Dog**: the original swapabxy tool (extended by RHH).
- **Mono Project**: the runtime.

License texts for all of the above are in `licenses/`.
