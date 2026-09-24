<#
.SYNOPSIS
  Builds the Android APK from the patched export, in Unity batch mode.

.DESCRIPTION
  1. Copies the editor automation (unity/Editor) into the project
  2. ConfigureAndroid: player settings, SDK/JDK, switch platform (reimports textures)
  3. BuildApk: rebuilds the AssetBundles for Android, then the APK into build/

  Each Unity run writes its log to export/<Name>/<step>.log.
  Run ./scripts/export.ps1 and ./scripts/patch.ps1 first.

.EXAMPLE
  ./scripts/build-apk.ps1
  ./scripts/build-apk.ps1 -SkipConfigure     # platform already switched
#>
param(
  [string]$Name = 'unity-dll',
  [string]$Unity = 'C:\Unity\2017.4.7f1\Editor\Unity.exe',
  [switch]$SkipConfigure
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$project = Join-Path $Root "export\$Name\ExportedProject"
if (-not (Test-Path $project)) { throw "$project not found. Run ./scripts/export.ps1 and ./scripts/patch.ps1 first." }
if (-not (Test-Path $Unity)) { throw "Unity not found at $Unity. Run ./scripts/setup-env.ps1." }

# The SDK tools Unity calls (avdmanager, sdkmanager) run on JAVA_HOME / PATH, not on
# Unity's JDK preference, and they break on JDK 9+ (javax.xml.bind is gone).
$jdk = Get-ChildItem 'C:\Java' -Directory -Filter 'jdk8*' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $jdk) { throw 'JDK 8 not found under C:\Java. Run ./scripts/setup-env.ps1.' }
$env:JAVA_HOME = $jdk.FullName
$env:Path = "$($jdk.FullName)\bin;$env:Path"

# 1. Editor automation
$editorDir = Join-Path $project 'Assets\Editor\BroforceAndroid'
New-Item -ItemType Directory -Force $editorDir | Out-Null
Copy-Item (Join-Path $Root 'unity\Editor\*.cs') $editorDir -Force

# 2. Official art for personal builds, from the git-ignored art/ folder:
#    art/icon.png   -> app icon
#    art/splash.png -> background of Unity's splash screen
#    Without art/ the build uses Unity's defaults.
$artDir = Join-Path $Root 'art'
$brandDir = Join-Path $project 'Assets\BroforceAndroid'
New-Item -ItemType Directory -Force $brandDir | Out-Null
foreach ($pair in @(@('icon.png', 'Icon.png'), @('splash.png', 'Splash.png'))) {
  $from = Join-Path $artDir $pair[0]
  if (Test-Path $from) {
    Copy-Item $from (Join-Path $brandDir $pair[1]) -Force
    Write-Host "[art] $($pair[0]) -> Assets/BroforceAndroid/$($pair[1])"
  }
}

function Invoke-Unity($step, $method) {
  $log = Join-Path $Root "export\$Name\$step.log"
  Write-Host "[unity] $method (log: $log)"
  $t = Get-Date
  $p = Start-Process $Unity -PassThru -Wait -WindowStyle Hidden -ArgumentList @(
    '-batchmode', '-quit', '-nographics',
    '-projectPath', "`"$project`"",
    '-executeMethod', $method,
    '-logFile', "`"$log`""
  )
  $errors = Select-String -Path $log -Pattern 'error CS\d+|\[BroforceAndroid\].*(fail|Missing)|Compilation failed' |
    Select-Object -First 15
  foreach ($e in $errors) { Write-Host "  $($e.Line)" }
  Write-Host ('[unity] {0} exit {1} in {2:N0} min' -f $step, $p.ExitCode, ((Get-Date) - $t).TotalMinutes)
  if ($p.ExitCode -ne 0) { throw "$method failed, see $log" }
}

# 2-3. Configure and build
if (-not $SkipConfigure) { Invoke-Unity 'configure-android' 'BroforceAndroid.Build.ConfigureAndroid' }
Invoke-Unity 'build-apk' 'BroforceAndroid.Build.BuildApk'

$apk = Join-Path $Root 'build\Broforce.apk'
if (Test-Path $apk) { Write-Host ('APK: {0} ({1:N0} MB)' -f $apk, ((Get-Item $apk).Length / 1MB)) }
