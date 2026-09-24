# Phase 0: Reconnaissance

Survey of Broforce Steam build `12964083` (Windows x64).

## Engine

| Item | Value | How to check |
|---|---|---|
| Unity version | **2017.4.7f1** | Properties of `UnityPlayer.dll` (FileVersion `2017.4.7.x`) |
| Scripting backend | **Mono** | `Broforce_beta_Data/Managed/Assembly-CSharp.dll` exists; there is no `GameAssembly.dll` or `il2cpp_data/` |
| Unity modules | Split (`UnityEngine.CoreModule.dll` etc.) | `Managed/` folder |

Consequence: on Android, Unity 2017.4 with Mono only builds **ARMv7 (32-bit)**. ARM64 would require IL2CPP, which in practice means upgrading the project to Unity 2018.2 or newer. For now the target is ARMv7.

## Relevant managed assemblies

| Assembly | What it is | Android plan |
|---|---|---|
| `Assembly-CSharp.dll`, `Assembly-CSharp-firstpass.dll` | Game code | Base of the port |
| `Assembly-UnityScript*.dll`, `Boo.Lang.dll` | Legacy UnityScript code | Keep as DLLs |
| `Rewired_Core.dll`, `Rewired_Windows_Lib.dll` | Input (Rewired) | The Windows lib won't run on Android. Investigate fallback to Unity input. Biggest risk in Phase 4 |
| `System.Windows.Forms.dll`, `System.Drawing.dll`, `CommonForms.dll` | Windows UI | Remove or stub |
| `PowerInspector.Runtime.dll`, `Sisus.*` | Runtime inspector and Odin serialization | Check whether the game depends on them at runtime |
| `Gif.Components.dll`, `GifComponents.dll` | GIF recording | Disable |
| `AlienFXManagedWrapper3.5.dll` | Alienware keyboard lighting | Disable |
| `*Import.dll` (ConsoleUtils, DataPlatform, Friends, GameDVR, Gamepad, Marketplace, Multiplayer, SmartGlass, Storage, StreamingInstall, TextSystems, Users, XIM, XboxOneCommon) | Xbox SDK wrappers | Remove or guard with platform checks |
| `SonyNP.dll`, `SonyPS4*.dll` | PS4 SDK | Remove |
| `UnityEngine.Networking.dll` | UNET | Check whether local multiplayer depends on it |

## Native plugins (`Broforce_beta_Data/Plugins`)

All are **Windows x64** and none work on Android:

- `CSteamworks.dll`, `steam_api64.dll`: Steamworks.NET → stub
- `NatCorder.dll`: video recording → disable
- `NintendoSDKPlugin.dll`, `nn_piaPlugin.dll`: Switch → remove
- `ConsoleUtils.dll`, `DataPlatform.dll`, `Friends.dll`, `GameDVR.dll`, `Gamepad.dll`, `LiveServices.dll`, `Marketplace.dll`, `Multiplayer.dll`, `SmartGlass.dll`, `Storage.dll`, `StreamingInstall.dll`, `TextSystems.dll`, `Users.dll`, `XIM.dll`, `UnityPluginLog.dll`: Xbox → remove

## Reference device

| Item | Value |
|---|---|
| Device | Samsung Galaxy S23 (SM-S911B, Snapdragon 8 Gen 2 / SM8550) |
| Android | 16 |
| `ro.product.cpu.abilist` | `arm64-v8a,armeabi-v7a,armeabi` ✅ supports ARMv7 |
| Controller | GameSir, wired over USB-C |

Since the USB port is taken by the controller, debugging has to go through **wireless adb** (`adb pair` / `adb connect`).

## AssetRipper notes (2.0.0)

- Script modes: `Decompiled`, `Hybrid`, `DllExportWithRenaming`, `DllExportWithoutRenaming`.
- Shader decompilation is a **paid** feature. In the free version shaders are exported as placeholders (`Dummy`). This is not really a loss: the PC shaders are DirectX bytecode and would have to be rewritten for GLES anyway.
- It can run without a UI: `AssetRipper.GUI.Free.exe --headless --port 5123` exposes an HTTP API (`/LoadFolder`, `/Settings/Update`, `/Export/UnityProject`), so the export can be automated.
