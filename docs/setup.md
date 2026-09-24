# Development setup

Everything here is Windows-only for now, because the game is exported from the Windows Steam build.

## Quick start

```powershell
# 1. Toolchain: Unity 2017.4.7f1 + Android module, JDK 8, legacy Android SDK
./scripts/setup-env.ps1

# 2. Export your Broforce install to a Unity project (export/unity-dll)
./scripts/export.ps1
```

Requirements before running the scripts:

- Broforce installed through Steam
- [7-Zip](https://www.7-zip.org) at `C:\Program Files\7-Zip\7z.exe`
- ~6 GB of free disk space

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

## Unity license

Unity 2017.4 still requires an activated license, even in batch mode. The only activation path that still works is through Unity Hub:

1. Install [Unity Hub](https://unity.com/download)
2. Sign in with a Unity account
3. **Preferences → Licenses → Add → Get a free personal license**

This writes `C:\ProgramData\Unity\Unity_lic.ulf`, which the 2017.4 editor also picks up. You don't need to install any editor through the Hub.

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
