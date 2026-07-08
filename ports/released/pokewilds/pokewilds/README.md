# Pokéwilds - PortMaster
This port of Pokewilds is made possible with the use of Westonpack by BinaryCounter.

## Installation
After installing the port, download the Windows game from https://github.com/SheerSt/pokewilds/releases and extract the `mods` and `app` folders, as well as `settings.txt`, into `ports/pokewilds/bin`.

You also need to install the following runtimes using the PortMaster app:
- Westonpack 0.2 (weston_pkg_0.2.squashfs) -- If you're not using a mainline firmware
- Java 17.0.13 (zulu17.54.21-ca-jre17.0.13-linux.squashfs)

## Default Gameplay Controls
| Button            | Action                                |
|--                 |--                                     |
| START             | Menu                                  |
| D-PAD / JOYSTICK  | Move                                  |
| A                 | Confirm                               |
| B                 | Cancel / Run                          |
| B (Hold)          | Stow Pokemon                          |
| L1 / R1           | Prev/Next (in build menu)             |

## Mods
Mods can enhance the look and gameplay. Some notable mods:

- [Gen 3 Overhaul Mod by BansheeStudio](https://github.com/BansheeStudio/PokemonWildsGen3Overhaul)
- [Pokewilds Android via Termux by Kuze2571](https://github.com/Kuze2571/Pokewilds-Termux)

More mods can be found on the [Pokewilds Discord Server](https://discord.gg/jdkV7F3AjA).

## Notes
This game has a large RAM footprint and uses more memory over time. Therefore it has been classified as an `ultra` port and will only run efficiently on Retroid Pocket 5, Retroid Pocket Mini, RetroDeck, etc. However, it *should* also run well on any device with more than `2GB` of memory like the Anbernic RG552. `2GB` devices may also work with the use of included zram tool, but it's untested.

Documentation: https://github.com/SheerSt/pokewilds/issues/476.

## Runtimes

This port requires the following runtimes in `PortMaster/libs`:

- **Java 17** — [zulu17.54.21-ca-jre17.0.13-linux.squashfs](https://github.com/PortsMaster/PortMaster-New/releases/download/2025-01-20_2237/zulu17.54.21-ca-jre17.0.13-linux.squashfs)

[Pharos](https://github.com/JeodC/RHH-Ports/releases/download/ports-latest/pharos.zip) will fetch these automatically when installing the port. Otherwise download them manually from the [runtimes folder](https://github.com/JeodC/RHH-Ports/tree/main/runtimes) and drop them in `PortMaster/libs`.

## Thanks
Pokéwilds Team -- The amazing game  
Nintendo -- The franchise