# Building RSDKv3 for this port

The shipped `RSDKv3` binary is built with Plus disabled. This guide covers rebuilding from source if you want to enable Plus-mode features (Amy and Knuckles as selectable characters).

## What the shipped binary uses

| Option | Value | Why |
|---|---|---|
| `RETRO_USE_HW_RENDER` | `OFF` | Retro handheld devices use gl4es; GLEW's GL 1.x/2.x path can have issues there |
| `RETRO_DISABLE_PLUS` | `ON` | Ships with the base three-character set (Sonic / Tails / Knuckles-via-mod) |

The build runs inside an aarch64 Debian chroot (or WSL2 equivalent). Build automation lives in `buildtools/ports/sonic/rsdkv3/` in the RHH-Ports repo.

## Enabling Plus characters (Amy, selectable Knuckles)

Origins SCD ships with Amy and Knuckles as Plus-DLC characters. Even with the correct Origins data extracted, the engine itself needs to be compiled with Plus enabled to spawn them in-game.

1. Clone the upstream decomp:
   ```
   git clone --recursive https://github.com/RSDKModding/RSDKv3-Decompilation.git
   cd RSDKv3-Decompilation
   ```
2. Configure with Plus enabled:
   ```
   cmake -B build \
     -DCMAKE_BUILD_TYPE=Release \
     -DRETRO_USE_HW_RENDER=OFF \
     -DRETRO_DISABLE_PLUS=OFF \
     -DCMAKE_EXE_LINKER_FLAGS="-pthread"
   cmake --build build --config Release -j$(nproc)
   ```
3. Copy `build/soniccd` into `ports/sonic.cd/` as `RSDKv3` (the port
   launcher expects that name), replacing the shipped binary.

Note: vanilla Origins' `SCD_sfx.acb` ships without audio data for Amy's voice clips (`OuttaHere`, `Giggle`, `AmyCaptured`). Using the Sonic Origins Ultrafix mod's replacement `SCD_sfx.acb` fills these in — see the main README for details.
