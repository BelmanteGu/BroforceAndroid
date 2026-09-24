# Input on Android (Rewired)

Broforce reads all input through [Rewired](https://guavaman.com/projects/rewired/). The game ships `Rewired_Core.dll` plus `Rewired_Windows_Lib.dll`, the Windows-only native input backend.

## Result

Rewired's Core runs on Android as it is. No replacement input layer is needed.

- `Rewired_Core.dll` is platform-neutral. On Android it reads controllers through Unity's input (`UnityEngine.Input`).
- `Rewired_Windows_Lib.dll` stays in the build. It's managed code that Rewired only uses when the platform is Windows, so on Android it's never loaded.
- The one blocker was in the game itself: `Rewired.InputManager.DetectPlatform()` (compiled into `Assembly-CSharp`) hardcodes `Platform.Windows`. The `rewired-platform` patch replaces it with `Hooks.GetRewiredPlatform()`, which returns `Platform.Android` (7) on Android and `Windows` (1) everywhere else. See [ADR 0001](adr/0001-patching-strategy.md).
- AssetRipper's re-written DLLs broke Rewired's serialized data (`TypeLoadException`), so the build uses the game's original DLLs.

On device the log (`adb logcat -s Unity`) shows:

```
[BroforceAndroid] rewired: isReady=True players=9
[BroforceAndroid]   Rewired.InputManager on 'Rewired Input Manager' enabled=True
[BroforceAndroid]     initialized = True
[BroforceAndroid]     criticalError = False
```

Menus and gameplay work with a keyboard on a Galaxy S23 and in the emulator. If Rewired fails to start, `Hooks.LogRewiredException` writes the reason to the log (the game ships with Rewired's own logging turned off).

## Still to verify

Physical gamepads on device: #17 (GameSir wired mapping) and #18 (a full mission with the gamepad).
