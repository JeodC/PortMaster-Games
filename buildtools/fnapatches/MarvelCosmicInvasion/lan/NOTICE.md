# EOS-over-LAN layer - license and provenance

The code in this folder (`ParisEngine.EOSLan.mm.cs`, `libEOSSDK-LAN.cs`) is original work, MIT licensed, same terms as the repo's top-level LICENSE.

## Provenance

- The LAN protocol, lobby model, and packet transport in `libEOSSDK-LAN.cs` were designed and written from scratch for this project.
- The shim in `ParisEngine.EOSLan.mm.cs` binds to the Epic Online Services C# wrapper types that the game itself ships inside `ParisEngine.dll`. Reproducing those type and method signatures is required for interoperability; the method bodies are RHH.
- No Epic SDK code, headers, or documentation text is included here or in the built artifacts.
- Game behavior (join flow, member sync, packet framing expectations) was understood by reading the game's own assemblies, the same basis as every other patch in this repo.
- The port's `libs/libEOSSDK-Linux-Shipping.so` is the stub from JohnnyonFlame's FNAPatches (credited in the port README, `licenses/johnnyonflame.LICENSE`), not Epic's SDK. This shim overrides the EOS methods used for LAN play; the stub safely no-ops the rest of the EOS surface the game still calls (achievements, stats, etc.), so it remains required.

## Isolation from the real online services

- This layer never contacts Epic. All traffic is UDP on the local subnet (port 55123) between the participating devices; nothing leaves the local network.
- No Epic or Steam account is used, read, or modified. Player identity is a local device name that exists only for the duration of a session.
- Only the port's local copy of the game is patched, on the device, from the user's own files. Installations elsewhere and their online play are untouched - this cannot interact with, impersonate, or disrupt real online sessions.

## What this is and isn't

- It replaces the game's online matchmaking with local-network discovery so two owned copies can play co-op on the same LAN. Both devices need the full game data, supplied by the user.
- It does not bypass any purchase, entitlement, or DLC check, and it does not defeat any copy protection. Accounts and ownership checks it skips gate an online service, not access to the game.

"Epic Online Services" and "EOS" are trademarks of Epic Games, Inc. The names appear here only to identify what the layer is compatible with; this project is not affiliated with or endorsed by Epic Games or Tribute Games.
