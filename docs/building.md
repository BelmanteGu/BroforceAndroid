# Building the APK

The whole pipeline, from your Steam install to an APK. Every step is a script in `scripts/` and can be re-run safely. For the one-time toolchain setup see [setup.md](setup.md).

One command runs everything (setup and export are skipped when already done):

```powershell
./scripts/build-all.ps1            # add -Install to install and launch over adb
```

Or step by step:

```powershell
./scripts/export.ps1          # 1. Steam install -> Unity project (export/unity-dll)       ~2 min
./scripts/patch.ps1           # 2. prune, patch DLLs, install rewritten shaders            ~1 min
./scripts/build-apk.ps1       # 3. switch to Android, rebuild bundles, build the APK       long, see below
./scripts/install.ps1 -Log    # 4. install on the phone and follow the log
```

The first time you open the exported project Unity imports ~15,000 assets, which takes 30 to 60 minutes. Switching the platform to Android re-imports every texture again (ETC2). Both are cached in `export/unity-dll/ExportedProject/Library`, so later builds are much faster.

## What each step does

### 1. Export (`export.ps1`)

Finds Broforce through Steam's library files and runs [AssetRipper](https://github.com/AssetRipper/AssetRipper) headless. The default mode keeps the game's original DLLs (`DllExportWithoutRenaming`), which is what the patcher works on. AssetRipper also restores the `assetBundleName` of every asset that came from a bundle.

### 2. Patch (`patch.ps1`)

- **Prune**: moves 35 unused assemblies (Windows UI, Xbox/PS4 SDKs, the PowerInspector debug tool) out of `Assets/Plugins`.
- **Shaders**: copies `shaders/*.shader` over the exported placeholders. See [shaders.md](shaders.md).
- **IL patches**: builds `runtime/` and `patcher/`, then rewrites a handful of methods in the game's DLLs. The list is in [`patcher/Patches.cs`](../patcher/Patches.cs) and the reasoning in [ADR 0001](adr/0001-patching-strategy.md):

| Patch | Why |
|---|---|
| `steam-init`, `steam-running`, `steam-enabled` | Steamworks P/Invokes throw on Android instead of reporting "no Steam" |
| `save-path` | Saves go to `Application.persistentDataPath` instead of the working directory |
| `rewired-platform` | Rewired was hardcoded to Windows; on Android it now runs on its Android path ([input.md](input.md)) |
| `alienfx` | The Alienware lighting SDK throws on the main menu |
| `quickcapture` | Dev video-capture tool that ran every frame |
| `sprite-mesh` | `SpriteBase.Awake` destroyed shared mesh assets, which Unity forbids in a player |
| `startup-log` | Device info, 60 FPS target, screen kept on, drawing under the display cutout |
| `rewired-errors`, `tick-log` | Diagnostics in the log: Rewired init failures, scene/camera/renderer dumps |
| `image-effects` | Disables the UnityScript Standard Assets post effects on Android |
| `save-thumbnail` | Save thumbnails are copied through a RenderTexture (raw bytes fail on ETC2) |
| `amplify-color`, `ssao` | Image effects that black out the screen on GLES are passed through |

### 3. Build (`build-apk.ps1`)

Copies the editor automation ([`unity/Editor`](../unity/Editor)) into the project and runs Unity in batch mode twice:

1. `ConfigureAndroid` (skip with `-SkipConfigure`):

   | Setting | Value | Why |
   |---|---|---|
   | Scripting backend | Mono, ARMv7 | The only option for Unity 2017.4 + the game's DLLs |
   | Graphics API | OpenGL ES 3 only | AssetRipper placeholder shaders don't compile for GLES2 |
   | Textures | ETC2 | Supported by every GLES3 device |
   | Orientation | Landscape left/right | |
   | Max aspect ratio | 2.4 | Unity's default 2.1 letterboxes 19.5:9 phones |
   | SDK | min 19, target 28 | Android 14+ refuses targets below 23; 28 is what the legacy SDK ships |
   | HW statistics | off | Its Play services lookup crashes Unity 2017's JNIBridge on Android 16 |

   At runtime the game also draws under the display cutout (`Hooks.UseDisplayCutout`).
2. `BuildApk`: before the bundles it
   - decodes baked lightmaps exported as native PC textures (DXT5/RGBM) to EXR, so Unity re-encodes them for Android;
   - keeps fully transparent textures uncompressed (ETC2 turned them into white rectangles).

   Then it assigns scene bundles, rebuilds all 16 AssetBundles for Android (LZ4, so they load straight from the APK) into `StreamingAssets` with the `.assetbundle` names the game expects, and builds `build/Broforce.apk`.

Logs: `export/unity-dll/configure-android.log` and `export/unity-dll/build-apk.log`.

## Checking shaders quickly

```powershell
./scripts/check-shaders.ps1
```

Builds a tiny Android APK containing one material per rewritten shader. It takes about a minute and catches GLES compile errors without a full game build.
