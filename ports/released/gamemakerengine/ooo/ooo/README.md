## Installation
Copy game data to `ooo/assets`.

## Notes
Needs instance culling due to 10560×8160 room, perform in `gml_GlobalScript_scCameraGameplay`

## Runtimes

This port requires the following:

- [gmtoolkit.aarch64](https://github.com/JeodC/gmtoolkit/releases/latest) placed in the `PortMaster/` folder.
- [gmloadernext.squashfs](https://github.com/JeodC/RHH-Ports/raw/main/runtimes/gmloadernext.squashfs) placed in the `PortMaster/libs/` folder.

[Pharos](https://github.com/JeodC/RHH-Ports/releases/download/ports-latest/pharos.zip) will fetch these automatically when installing the port. Otherwise download them manually and add them to the correct folders.

## Thanks

JohnnyOnFlame -- GMLoader-Next  