# AM2R - 64-bit
The latest AM2R experience is v1.6b2. Follow the below steps to obtain this version and use it with your retro device.

## Installation
You will need the following **zip files** (copy all files to `ports/am2r/assets`):

- `am2r-another-metroid-2-remake-1-1.zip` -- The base game's Windows version (search for this on the web, DoctorM64 is a known and trusted source)
- **MANDATORY:** The **AM2R 1.6b Patch File**: This patch, 1.6b2, is what makes AM2R 64-bit.
  - Download: [AM2R 1.6b patch](https://github.com/AM2R-Community-Developers/ProfessorG64/releases/download/1.6b2/AM2R_1.6b2_windows.zip)
- **OPTIONAL:** The **HQ Audio / Autopatcher Data**: Use this if you want the High-Quality in-game music.
  - Download: [1.5.5 Autopatcher zip](https://github.com/AM2R-Community-Developers/AM2R-Autopatcher-Windows/archive/refs/heads/master.zip)

Copy all zip files to `ports/am2r/assets` and run the port. It may take some time to install.

## Runtimes

This port requires the following:

- [gmtoolkit.aarch64](https://github.com/JeodC/gmtoolkit/releases/latest) placed in the `PortMaster/` folder.
- [gmloadernext.squashfs](https://github.com/JeodC/RHH-Ports/raw/main/runtimes/gmloadernext.squashfs) placed in the `PortMaster/libs/` folder.

[Pharos](https://github.com/JeodC/RHH-Ports/releases/download/ports-latest/pharos.zip) will fetch these automatically when installing the port. Otherwise download them manually and add them to the correct folders.

## Thanks
AM2R Team -- The game  
JohnnyOnFlame -- GMLoader-Next and original AM2R port  
Jeod -- Enhancements to GMLoader-Next and 64-bit port update  
hotcereal -- The 3:2 aspect ratio patch  
