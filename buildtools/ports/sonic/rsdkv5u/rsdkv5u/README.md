# RSDKv5U helper tools

A set of small C utilities used by the `sonic.1` and `sonic.2` port
patchscripts to turn Sonic Origins input data into the layout the RSDKv4
engine expects. Built as aarch64 static-ish binaries and shipped in each
port's `tools/` folder.

| Tool | Purpose |
|---|---|
| `rsdkv5u-extract` | Unpack a Sonic Origins `Sonic{1,2}u.rsdk` container. Reads the RSDKv4 outer wrapper, looks up file paths via MD5 hash against a filelist, decrypts each payload with RSDKv5U's XOR + nibble-swap algorithm, writes loose files to `Data/` + `Bytecode/`. Algorithm ported from [`RSDKv5-Decompilation/RSDKv5/RSDK/Core/Reader.cpp`](https://github.com/RSDKModding/RSDKv5-Decompilation/blob/main/RSDKv5/RSDK/Core/Reader.cpp). |
| `wav-normalize` | Downmix PCM16 WAV to mono 44.1kHz and peak-normalize to a target dBFS. Origins SFX ship as stereo 48kHz at quiet levels; RSDKv4's mixer assumes mono frames and mobile-loud levels, so this reshapes to the engine-compatible format. |
| `wav-speed` | Tempo-change a PCM16 WAV without pitch shift. Linear resamples the sample buffer to emit `src_frames / ratio` frames at the ORIGINAL sample rate, so playback time shrinks by the ratio while pitch is preserved. Used to synthesize Sonic 2's `_F` speed-shoes music variants (Origins doesn't ship them; mobile `_F` tracks are effectively the base track at 1.2x per the RSDK modding docs). |
| `patch-gameconfig` | In-place edit `Data/Game/GameConfig.bin` after extraction. Flips `game.playMode` and `game.hasPlusDLC` to 1 (unlocks Anniversary behavior + Plus roster in scripts), and expands the 4-entry Players list to the full 7-entry Plus roster. Note that users must still build RSDKv4 with Plus support to use Plus features. |

## Building

```
aarch64-linux-gnu-gcc -O2 -static-libgcc -o rsdkv5u-extract   rsdkv5u-extract.c
aarch64-linux-gnu-gcc -O2 -static-libgcc -o wav-normalize     wav-normalize.c   -lm
aarch64-linux-gnu-gcc -O2 -static-libgcc -o wav-speed         wav-speed.c
aarch64-linux-gnu-gcc -O2 -static-libgcc -o patch-gameconfig  patch-gameconfig.c
aarch64-linux-gnu-strip rsdkv5u-extract wav-normalize wav-speed patch-gameconfig
```

Copy the resulting binaries into each port's `tools/` folder:

```
cp rsdkv5u-extract wav-normalize wav-speed patch-gameconfig \
   ../../../../ports/released/sonic-collection/sonic.1/sonic.1/tools/
cp rsdkv5u-extract wav-normalize wav-speed patch-gameconfig \
   ../../../../ports/released/sonic-collection/sonic.2/sonic.2/tools/
```

## License

MIT. See `LICENSE`.
