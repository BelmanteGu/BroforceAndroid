<#
.SYNOPSIS
  One command from your Steam install to an APK: setup, export, patch, build, and
  optionally install.

.DESCRIPTION
  Runs, in order:
    1. setup-env.ps1   Unity 2017.4.7f1 + Android module, JDK 8, legacy Android SDK
                       (skipped when Unity is already installed, unless -Setup)
    2. export.ps1      your Broforce install -> Unity project in export/
                       (skipped when the export exists, unless -ReExport)
    3. patch.ps1       Android patches, shaders, audio fixes
    4. build-apk.ps1   asset bundles + build/Broforce.apk
    5. install.ps1     only with -Install: adb install and launch

  Each step can also be run on its own; see docs/building.md.

.EXAMPLE
  ./scripts/build-all.ps1
.EXAMPLE
  ./scripts/build-all.ps1 -GamePath 'D:\SteamLibrary\steamapps\common\Broforce' -Install
#>
param(
  [string]$GamePath,
  [switch]$Setup,
  [switch]$ReExport,
  [switch]$Install
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$started = Get-Date

function Step([string]$title, [scriptblock]$body) {
  Write-Host ''
  Write-Host "==> $title" -ForegroundColor Cyan
  & $body
}

if ($Setup -or -not (Test-Path 'C:\Unity\2017.4.7f1\Editor\Unity.exe')) {
  Step 'Setting up the environment' { & "$PSScriptRoot\setup-env.ps1" }
}

if ($ReExport -or -not (Test-Path (Join-Path $Root 'export\unity-dll\ExportedProject'))) {
  Step 'Exporting Broforce with AssetRipper' {
    $exportArgs = @{}
    if ($GamePath) { $exportArgs.GamePath = $GamePath }
    if ($ReExport) { $exportArgs.Force = $true }
    & "$PSScriptRoot\export.ps1" @exportArgs
  }
}

Step 'Patching' { & "$PSScriptRoot\patch.ps1" }
Step 'Building the APK' { & "$PSScriptRoot\build-apk.ps1" }
if ($Install) { Step 'Installing' { & "$PSScriptRoot\install.ps1" } }

Write-Host ''
Write-Host ("Done in {0:mm\:ss}: {1}" -f ((Get-Date) - $started), (Join-Path $Root 'build\Broforce.apk')) -ForegroundColor Green
