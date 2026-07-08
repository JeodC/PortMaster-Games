# Building the FNAPatches artifacts

This folder contains the sources for the binaries in the MARVEL Cosmic Invasion port. The port carries only the built artifacts; rebuild them from here.
The approach follows [JohnnyonFlame/FNAPatches](https://github.com/JohnnyonFlame/FNAPatches) - offline MonoMod mixins plus a Cecil publicizer - adapted for MCI's split across `ParisEngine.dll` and `Game.exe`.

| Artifact | Built from | Deploys to |
|---|---|---|
| `libFNA3D.so.0` | `FNA3D/build_fna3d_astc.sh` + `FNA3D/fna3d-astc-r8.patch` | `<port>/libs/` |
| `ParisEngine.MCIPatches.mm.dll` | `MarvelCosmicInvasion/ParisEngine.MCIPatches.mm.cs` + `lan/` sources (section 4) | `<port>/patches/` |
| `Game.MCIPatches.mm.dll` | `MarvelCosmicInvasion/Game.MCIPatches.mm.cs` | `<port>/patches/` |
| `MCIRepacker.exe` | `MarvelCosmicInvasion/MCIRepacker.cs` | `<port>/tools/` |

## Prerequisites

- **Docker** with aarch64 emulation — for `libFNA3D` (native ARM64).
- **A mono 6.12.x toolchain** for the managed builds. The official `mono:latest` container (6.12.0.182) works; the device runtime is 6.12.0.122. Either is fine because MonoMod reads the compiled IL - **but it must be `mcs`, not `csc`**. csc records the publicized reference with a different assembly identity and MonoMod then rejects it (`MapDependency` failure).
- **Game reference assemblies**, from your own MCI copy:
  - `ParisEngine.dll`, `FNA.dll`, and `Game.exe` - these must come from the game installation.
  - the game's other managed deps, so `mcs`/MonoMod can resolve ParisEngine's references: `Steamworks.NET.dll`, `Newtonsoft.Json.dll`, `NLog.dll`, `NVorbis.dll`, `Ionic.Zlib.dll`, `ParisSerializers.dll`, `NBug.dll`.
- **MonoMod** - copy the port's `monomod/` (MonoMod.exe + Mono.Cecil*.dll + MonoMod.*.dll). This is the same patcher the device applies.

## 1. libFNA3D.so.0 (native, aarch64)

```bash
docker run --rm --platform linux/aarch64 \
  -v "$PWD/FNA3D:/host" ubuntu:24.04 bash /host/build_fna3d_astc.sh
```

Clones FNA3D 24.04, applies `fna3d-astc-r8.patch` (adds ASTC 4x4/5x5/6x6/8x8 + R8 surface formats, GL/GLES only), disables the Vulkan driver (the port forces `FNA3D_FORCE_DRIVER=OpenGL`), builds, and drops `libFNA3D.so.0.24.04` next to the script. Copy it to `<port>/libs/libFNA3D.so.0`.

## 2. Mixins + MCIRepacker (managed, architecture-independent)

Stage a work dir containing the game references, the port's MonoMod, and the four sources from this repo (`Publicize.cs`, the two `*.mm.cs`, `MCIRepacker.cs`), then run in a mono container (`docker run --rm -v "$PWD:/work" mono:latest bash …`):

```bash
cd /work

# Publicized compile-time reference. The mixins touch private members; MonoMod
# merges the patch types back into the target, so it stays legal at runtime.
mcs -target:exe -out:Publicize.exe -r:Mono.Cecil.dll Publicize.cs
MONO_PATH=. mono Publicize.exe ParisEngine.dll ParisEngine.pub.dll

# Engine mixin
mcs -target:library -out:ParisEngine.MCIPatches.mm.dll -lib:. \
    -r:ParisEngine.pub.dll -r:FNA.dll -r:MonoMod.exe ParisEngine.MCIPatches.mm.cs

# Game mixin (references the pristine Game.exe + the publicized ParisEngine)
mcs -target:library -out:Game.MCIPatches.mm.dll -lib:. \
    -r:Game.exe -r:ParisEngine.pub.dll -r:FNA.dll -r:NBug.dll -r:MonoMod.exe Game.MCIPatches.mm.cs

# Texture repacker (standalone)
mcs -unsafe -optimize -out:MCIRepacker.exe MCIRepacker.cs
```

Deploy the two: `*.mm.dll` to `<port>/patches/`, `MCIRepacker.exe` goes to `<port>/tools/`.

## 3. Verify off-device (optional, recommended)

Apply the mixins to pristine copies exactly as the device patchscript will. MonoMod auto-discovers `<target>.*.mm.dll` beside the target; both must exit 0 and emit a `MONOMODDED_*`:

```bash
cp ParisEngine.dll pe_target.dll && mv pe_target.dll ParisEngine.dll    # mixin sits beside it
MONOMOD_DEPDIRS=.:/usr/lib/mono/4.5 mono MonoMod.exe ParisEngine.dll    # -> MONOMODDED_ParisEngine.dll
cp -f MONOMODDED_ParisEngine.dll ParisEngine.dll                        # Game mixin needs the patched engine
MONOMOD_DEPDIRS=.:/usr/lib/mono/4.5 mono MonoMod.exe Game.exe           # -> MONOMODDED_Game.exe
```

The device patchscript re-runs this on the user's own assemblies at first launch, then AOT-compiles both results.

## 4. LAN co-op build

`MarvelCosmicInvasion/lan/` holds an EOS-over-LAN layer that replaces Epic Online Services with local-network discovery, so two devices on the same network can play co-op (see the folder's NOTICE.md for licensing and provenance). The shipped `patches/*.mm.dll` are built this way: same pipeline as section 2, but define `MCI_LAN` and feed the engine mixin two extra sources. The define also compiles out the base mixin's EOS/networking no-ops, so a mixin pair is either fully stock or fully LAN - don't mix them. Section 2's commands as written produce the stock, online-disabled build.

```bash
# Engine mixin, LAN build (base + EOS shim + LAN core in one dll)
mcs -target:library -d:MCI_LAN -out:ParisEngine.MCIPatches.mm.dll -lib:. \
    -r:ParisEngine.pub.dll -r:FNA.dll -r:MonoMod.exe \
    ParisEngine.MCIPatches.mm.cs lan/ParisEngine.EOSLan.mm.cs lan/libEOSSDK-LAN.cs

# Game mixin, LAN build (adds the multiplayer menu trim)
mcs -target:library -d:MCI_LAN -out:Game.MCIPatches.mm.dll -lib:. \
    -r:Game.exe -r:ParisEngine.pub.dll -r:FNA.dll -r:NBug.dll -r:MonoMod.exe Game.MCIPatches.mm.cs
```

Weave and AOT exactly as in section 3; the AOT-pair rule below applies unchanged. Every
device in a session needs the LAN build (a stock build can't see or join LAN lobbies),
the full game data, and UDP port 55123 open between them - discovery is subnet broadcast.

## Notes

- **AOT `ParisEngine.dll.so` and `Game.exe.so` together.** MonoMod preserves the MVID, so mono can't tell a re-patched assembly from a stale AOT image, so a mismatched pair crashes at startup in seemingly random Renderer accessors.
- **`mcs`, never `csc`** (see Prerequisites).
