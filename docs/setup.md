# Development setup

Everything here is Windows-only for now, because the game is exported from the Windows Steam build.

## Quick start

```powershell
# 1. Toolchain: Unity 2017.4.7f1 + Android module, JDK 8, legacy Android SDK
./scripts/setup-env.ps1

# 2. Export your Broforce install to a Unity project (export/unity-dll)
./scripts/export.ps1

# 3. Patch the exported game DLLs for Android
./scripts/patch.ps1
```

Requirements before running the scripts:

- Broforce installed through Steam
- [7-Zip](https://www.7-zip.org) at `C:\Program Files\7-Zip\7z.exe`
- [.NET SDK](https://dotnet.microsoft.com/download) 8 or newer (for the patcher)
- ~6 GB of free disk space

## Patching

`scripts/patch.ps1` builds two small projects and applies them to `export/unity-dll`:

- `runtime/`: `BroforceAndroid.Runtime.dll`, our own code (net35, like Unity 2017.4's Mono profile) that patched game methods call into. It's copied into `Assets/Plugins`.
- `patcher/`: a Mono.Cecil tool that rewrites specific methods in `Assembly-CSharp.dll` and `Assembly-CSharp-firstpass.dll`. The list lives in [`patcher/Patches.cs`](../patcher/Patches.cs).

The originals are backed up to `export/unity-dll/original-dlls` on the first run, and every run starts from that backup. If any patch can't find its target, nothing is written. Why IL patching instead of editing decompiled code: [ADR 0001](adr/0001-patching-strategy.md).

To inspect the result, decompile the patched DLL with [ILSpy](https://github.com/icsharpcode/ILSpy) (`dotnet tool install ilspycmd --tool-path tools/ilspy`).

## What `setup-env.ps1` installs

| Component | Version | Default location | Why this version |
|---|---|---|---|
| Unity editor | **2017.4.7f1** (changeset `de9eb5ca33c5`) | `C:\Unity\2017.4.7f1` | Same version the game was built with |
| Android Build Support | 2017.4.7f1 | `...\Editor\Data\PlaybackEngines\AndroidPlayer` | |
| JDK | Temurin **8** | `C:\Java\jdk8u*` | Unity 2017.4 and its Gradle/Android plugin fail on JDK 11+ |
| Android SDK Tools | **26.1.1** (`sdk-tools-windows-4333796`) | `C:\Android\sdk-legacy` | Unity 2017.4 looks for the old `tools/` layout; newer SDKs only ship `cmdline-tools/` |
| Build-tools | **28.0.3** | same | Compatible with the Gradle plugin bundled with 2017.4 |
| Platform | **android-28** | same | |

The Unity installers are NSIS archives, so the script extracts them with 7-Zip instead of running them. No admin rights and no Unity Hub needed for the editor itself. The legacy SDK is installed in its own folder so it doesn't interfere with a newer SDK you may already have.

NDK is not needed: the Mono backend doesn't compile native code.

The Unity installer normally installs the **Visual C++ 2010** runtime as a prerequisite. Because we extract it instead, `setup-env.ps1` installs it separately (you'll get an admin prompt). Without it `Unity.exe` exits immediately with `0xC0000135` (DLL not found).

## Unity license

Unity 2017.4 needs an activated license, even in batch mode, and it only reads the **legacy** license file `C:\ProgramData\Unity\Unity_lic.ulf`.

**Activate from the 2017.4 editor itself:**

1. Run `C:\Unity\2017.4.7f1\Editor\Unity.exe` (no project needed)
2. Sign in with your Unity account in the license window
3. Pick **Unity Personal**, answer the short survey and confirm
4. Close the editor. `C:\ProgramData\Unity\Unity_lic.ulf` should now exist

Don't rely on the current Unity Hub for this. Since 3.x it's distributed as an MSIX package: it only writes the new entitlement license (`UnityEntitlementLicense.xml`), inside its own sandboxed folder, and never creates the `.ulf` that 2017.4 needs.

## Pointing Unity to the JDK and SDK

In **Edit → Preferences → External Tools**:

- **SDK**: `C:\Android\sdk-legacy`
- **JDK**: `C:\Java\jdk8u...`

The build scripts will set these automatically in batch mode.

## Export modes

`scripts/export.ps1 -ScriptMode <mode>`:

| Mode | Output folder | Use |
|---|---|---|
| `DllExportWithoutRenaming` (default) | `export/unity-dll` | Keeps the original game DLLs. Opens with the fewest compile errors |
| `Decompiled` | `export/unity-src` | Game code as C#. Reference for reading and patching |

Load takes ~20 s and export ~2 min on a recent machine. The exported project is ~1.2 GB.

**Never commit anything under `export/` or `tools/`.** Both folders are git-ignored.
