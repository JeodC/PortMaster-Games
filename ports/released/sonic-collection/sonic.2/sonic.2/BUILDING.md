# Building RSDKv4 for this port

The shipped `RSDKv4` binary is built with Plus disabled. This guide
covers rebuilding from source if you want to enable Plus-mode characters
(Amy, Knuckles & Tails, etc.).

## What the shipped binary uses

| Option | Value | Why |
|---|---|---|
| `RETRO_REVISION` | `3` | Universal binary; runtime detects Origins vs mobile data |
| `RETRO_USE_HW_RENDER` | `OFF` | Menu Recreation mod supplies a 2D menu; no GL required |
| `RETRO_DISABLE_PLUS` | `ON` | Four-character classic set (Sonic / Tails / Knuckles / Sonic & Tails) |

The build runs inside an aarch64 Debian chroot (or WSL2 equivalent).
Build automation lives in `buildtools/ports/sonic/rsdkv4/` in the RHH-Ports repo.

## Enabling Plus characters (Amy, extra sidekicks)

This adds the Anniversary-mode roster: `SONIC AND TAILS`,
`KNUCKLES AND TAILS`, `AMY`, `AMY AND TAILS`. Sonic 2 in particular
gates Amy selection on `Game.hasPlusDLC` at the script level AND on
the engine-side Plus implementation — both must be in place.

1. Clone the upstream decomp:
   ```
   git clone --recursive https://github.com/RSDKModding/RSDKv4-Decompilation.git
   cd RSDKv4-Decompilation
   ```
2. Configure with Plus enabled:
   ```
   cmake -B build \
     -DCMAKE_BUILD_TYPE=Release \
     -DRETRO_REVISION=3 \
     -DRETRO_USE_HW_RENDER=OFF \
     -DRETRO_DISABLE_PLUS=OFF \
     -DCMAKE_EXE_LINKER_FLAGS="-pthread"
   cmake --build build --config Release -j$(nproc)
   ```
3. Copy `build/RSDKv4` into `ports/sonic.2/`, replacing the shipped binary.
   The port's patchscript already expands `Data/Game/GameConfig.bin`
   to the full seven-slot Plus roster and sets `game.hasPlusDLC = 1`
   at extraction time, so Amy shows up correctly in the dev menu as
   soon as you boot the Plus-enabled binary. No RetroED work needed.
