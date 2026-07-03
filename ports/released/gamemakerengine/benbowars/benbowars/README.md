## Installation
Download the BenboWARS demo from Steam and add all files to `benbowars/assets`.

## Notes
The install patcher disables the GMLive debug extension left in the demo build
(it crashes gmloader-next on device) and applies performance patches for weak
devices: textures are ASTC-externalized and repacked, off-view wallback scenery
skips its draw entirely, and the camera deactivates far-off-view wallbacks
every 10 frames (the game's own instance_activate_region call wakes them as
they scroll back in). The densest level holds ~1400 instances, most of them
wallbacks, so this is the difference between dispatching ~1400 events per
frame and ~100.

Tagged "power" until the patched build is verified on weaker hardware.

## Thanks
Mr. Videogames -- The game  
JohnnyOnFlame -- GMLoader-Next  
