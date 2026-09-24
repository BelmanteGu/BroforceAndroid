# ADR 0001: Patching strategy for game code

- **Status:** Accepted (to be validated by #5, the first time the project opens in Unity)
- **Issue:** #4

## Context

The port has to change the game's behavior, but this repository can't contain the game's code, decompiled or not. Whatever we commit must be our own code, applied on top of each contributor's local export.

A survey of the decompiled code (`scripts/export.ps1 -ScriptMode Decompiled`) shows that the changes needed to boot on Android are few and very localized:

| Problem | Where | Change |
|---|---|---|
| Every Steam guard throws `DllNotFoundException` (P/Invoke into `CSteamworks`) instead of returning false. 28 call sites, including saves and language | `SteamController.IsSteamEnabled()` | Return `false` |
| Language setup calls `SteamAPI.IsSteamRunning()` directly | `LanguageManager` (one call) | Skip the Steam branch |
| Saves and custom levels use paths relative to the working directory (`/` on Android) | `FileIO.GetPlatformDataPath(string)`, which returns `path` unchanged | Prefix with `Application.persistentDataPath` |
| Rewired is forced to Windows | `Rewired.InputManager.DetectPlatform()` (compiled into `Assembly-CSharp`), which hardcodes `Platform.Windows` | `Platform.Android` |
| `AlienFXControllerManaged.Start()` throws (native `LightFX.dll`) in the main menu and campaign scenes | `AlienFXControllerManaged` | No-op |
| GIF/video capture components (`GifController`, `QuickCapture`/NatCorder) sit in the campaign scene | Those components | No-op |

Larger work items (rebuilding AssetBundles #24, shaders #10, input tweaks #17) are asset/editor work, not code patches.

## Options considered

1. **Decompiled project + source `.patch` files.** Readable, but ~6,900 decompiled files (1,935 in `Assembly-CSharp` alone) must compile cleanly under Unity 2017.4. Decompiler output often doesn't. Diffs also break whenever AssetRipper/ILSpy output changes. We'd be maintaining a fork of generated code to change a dozen methods.
2. **Original DLLs + IL patching with Mono.Cecil.** The project uses the game's own compiled assemblies (`DllExportWithoutRenaming`, fewest compile errors). A small .NET tool rewrites specific method bodies. Patches are exact, reproducible, and don't depend on decompiler output.
3. **Original DLLs + runtime hooks (Harmony).** No build step, but runtime detouring on Mono ARMv7 in Unity 2017 is fragile. Rejected.

## Decision

**Option 2**, in two layers:

- **`patcher/`**: a small .NET console tool using Mono.Cecil. It takes the exported project, patches `Assembly-CSharp.dll` (and `Assembly-CSharp-firstpass.dll` if needed) in place and keeps a backup of the originals. Each patch is a named, self-describing unit ("replace body of `SteamController.IsSteamEnabled` with `return false`") that fails loudly if its target method is missing. That way a game update can't be silently mis-patched.
- **`BroforceAndroid.Runtime.dll`**: our own C# code (net35, referencing `UnityEngine`) for anything more than a one-liner. The patcher redirects game methods to call into it. New behavior is written as normal C#, never as hand-written IL.

The decompiled export (`export/unity-src`) stays a **local, read-only reference** for finding patch targets. It's never compiled or committed.

## Consequences

- The export mode for builds is `DllExportWithoutRenaming` (`export/unity-dll`).
- Windows-only managed assemblies (`System.Windows.Forms`, `System.Drawing`, console `*Import.dll`, etc.) can simply be removed from the project when nothing on the runtime path references them. Assemblies that `Assembly-CSharp` references (`AlienFXManagedWrapper3.5`, `Gif.Components`, `XboxOneCommonImport`) stay, and only their call sites are neutralized.
- Patches are tied to Steam build `12964083`. The patcher should print the build it expects and refuse unknown targets.
- If option 2 hits a wall (e.g. an asset references a script type we need to change heavily), we revisit this ADR rather than mixing strategies ad hoc.
