<#
.SYNOPSIS
  Installs (or replaces) the APK on the phone and launches it.

.EXAMPLE
  ./scripts/install.ps1                       # newest APK under build/
  ./scripts/install.ps1 -Apk path\to\app.apk
  ./scripts/install.ps1 -Log                  # then follow the Unity log
#>
param(
  [string]$Apk,
  [string]$Serial,
  [switch]$Log
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

if (-not $Apk) {
  $Apk = Get-ChildItem (Join-Path $Root 'build') -Recurse -Filter *.apk -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
  if (-not $Apk) { throw 'No APK found under build/. Pass -Apk <path>.' }
}

$adb = @()
if ($Serial) { $adb += @('-s', $Serial) }

# Read the package name from the APK so this works whatever the bundle id is.
$aapt = Get-ChildItem 'C:\Android\sdk-legacy\build-tools' -Recurse -Filter aapt.exe -ErrorAction SilentlyContinue | Select-Object -First 1
$package = $null
if ($aapt) {
  $badging = & $aapt.FullName dump badging $Apk 2>$null
  $package = [regex]::Match(($badging -join "`n"), "package: name='([^']+)'").Groups[1].Value
}

Write-Host "[install] $Apk"
adb @adb install -r $Apk
if ($LASTEXITCODE -ne 0) { throw 'adb install failed' }

if ($package) {
  Write-Host "[launch] $package"
  adb @adb shell monkey -p $package -c android.intent.category.LAUNCHER 1 | Out-Null
} else {
  Write-Warning 'Could not read the package name; launch the app manually.'
}

if ($Log) {
  $logArgs = @{ Clear = $true }
  if ($Serial) { $logArgs.Serial = $Serial }
  & (Join-Path $PSScriptRoot 'logcat.ps1') @logArgs
}
