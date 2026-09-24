<#
.SYNOPSIS
  Installs the toolchain needed to open and build the project, without Unity Hub.

.DESCRIPTION
  - Unity 2017.4.7f1 editor + Android Build Support (extracted with 7-Zip, no admin needed)
  - Temurin JDK 8 (Unity 2017.4 does not work with JDK 11+)
  - A separate "legacy" Android SDK with SDK Tools 26.1.1, build-tools 28.0.3 and platform 28
    (Unity 2017.4 expects the old tools/ layout; your existing SDK is left untouched)

  Unity still needs a license: install Unity Hub once, sign in and activate a free
  Personal license. The activation is stored in C:\ProgramData\Unity\Unity_lic.ulf
  and is picked up by this editor too.

  Requires 7-Zip (https://www.7-zip.org).

.EXAMPLE
  ./scripts/setup-env.ps1
#>
param(
  [string]$UnityDir = 'C:\Unity\2017.4.7f1',
  [string]$JavaDir = 'C:\Java',
  [string]$SdkDir = 'C:\Android\sdk-legacy',
  [string]$DownloadDir = 'C:\Unity\_downloads',
  [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$UnityChangeset = 'de9eb5ca33c5'
$Downloads = [ordered]@{
  'UnitySetup64-2017.4.7f1.exe' = "https://download.unity3d.com/download_unity/$UnityChangeset/Windows64EditorInstaller/UnitySetup64-2017.4.7f1.exe"
  'UnitySetup-Android-Support-for-Editor-2017.4.7f1.exe' = "https://download.unity3d.com/download_unity/$UnityChangeset/TargetSupportInstaller/UnitySetup-Android-Support-for-Editor-2017.4.7f1.exe"
  'jdk8.zip' = 'https://api.adoptium.net/v3/binary/latest/8/ga/windows/x64/jdk/hotspot/normal/eclipse'
  'sdk-tools-windows-4333796.zip' = 'https://dl.google.com/android/repository/sdk-tools-windows-4333796.zip'
}

if (-not (Test-Path $SevenZip)) { throw "7-Zip not found at $SevenZip" }

function Expand-With7z($archive, $dest) {
  & $SevenZip x $archive "-o$dest" -y -bso0 -bsp0
  if ($LASTEXITCODE -ne 0) { throw "7-Zip failed on $archive" }
}

# --- Download ---
New-Item -ItemType Directory -Force $DownloadDir | Out-Null
foreach ($name in $Downloads.Keys) {
  $out = Join-Path $DownloadDir $name
  if (Test-Path $out) { Write-Host "[skip] $name already downloaded"; continue }
  Write-Host "[download] $name"
  Invoke-WebRequest $Downloads[$name] -OutFile $out -UseBasicParsing
}

# --- Unity editor ---
if (Test-Path "$UnityDir\Editor\Unity.exe") {
  Write-Host "[skip] Unity editor already at $UnityDir"
} else {
  Write-Host "[install] Unity 2017.4.7f1 -> $UnityDir"
  Expand-With7z (Join-Path $DownloadDir 'UnitySetup64-2017.4.7f1.exe') $UnityDir
}

# --- Android Build Support ---
$androidPlayer = "$UnityDir\Editor\Data\PlaybackEngines\AndroidPlayer"
if (Test-Path "$androidPlayer\UnityEditor.Android.Extensions.dll") {
  Write-Host '[skip] Android Build Support already installed'
} else {
  Write-Host '[install] Android Build Support'
  $tmp = Join-Path $DownloadDir '_android_tmp'
  Expand-With7z (Join-Path $DownloadDir 'UnitySetup-Android-Support-for-Editor-2017.4.7f1.exe') $tmp
  # The NSIS payload lands in a folder named like "$INSTDIR$_59_"
  $payload = Get-ChildItem -LiteralPath $tmp -Directory | Where-Object { $_.Name -like '$INSTDIR*' } | Select-Object -First 1
  if (-not $payload) { throw 'Could not find the Android module payload' }
  Move-Item -LiteralPath $payload.FullName -Destination $androidPlayer
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

# --- JDK 8 ---
$jdk = Get-ChildItem $JavaDir -Directory -Filter 'jdk8*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($jdk) {
  Write-Host "[skip] JDK 8 already at $($jdk.FullName)"
} else {
  Write-Host "[install] JDK 8 -> $JavaDir"
  New-Item -ItemType Directory -Force $JavaDir | Out-Null
  Expand-With7z (Join-Path $DownloadDir 'jdk8.zip') $JavaDir
  $jdk = Get-ChildItem $JavaDir -Directory -Filter 'jdk8*' | Select-Object -First 1
}

# --- Legacy Android SDK ---
if (-not (Test-Path "$SdkDir\tools\bin\sdkmanager.bat")) {
  Write-Host "[install] Android SDK Tools 26.1.1 -> $SdkDir"
  New-Item -ItemType Directory -Force $SdkDir | Out-Null
  Expand-With7z (Join-Path $DownloadDir 'sdk-tools-windows-4333796.zip') $SdkDir
}
$env:JAVA_HOME = $jdk.FullName
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
Write-Host '[install] SDK packages (you may be asked to accept licenses)'
'y','y','y','y','y','y','y' | & "$SdkDir\tools\bin\sdkmanager.bat" --licenses --sdk_root=$SdkDir | Out-Null
& "$SdkDir\tools\bin\sdkmanager.bat" --sdk_root=$SdkDir 'platform-tools' 'build-tools;28.0.3' 'platforms;android-28' | Out-Null

Write-Host ''
Write-Host 'Done.'
Write-Host "  Unity:   $UnityDir\Editor\Unity.exe"
Write-Host "  JDK:     $($jdk.FullName)"
Write-Host "  SDK:     $SdkDir"
if (-not (Test-Path 'C:\ProgramData\Unity\Unity_lic.ulf')) {
  Write-Warning 'No Unity license found. Install Unity Hub, sign in and activate a free Personal license.'
}
