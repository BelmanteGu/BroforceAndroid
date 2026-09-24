<#
.SYNOPSIS
  Patches Unity 2017.4's Android player so apps don't crash on Android 16.

.DESCRIPTION
  Replaces bitter.jnibridge.JNIBridge in the Android player's classes.jar with the
  version in unity/Android (same signatures, plus handling for default interface
  methods that newer Android versions add; see the comment in the source).

  Without it, the player dies ~5 s after launch on Android 16 with:
    NoSuchMethodError: ServiceConnection.onServiceConnected(ComponentName, IBinder, IBinderSession)

  The original jars are kept as classes.jar.orig; re-running starts from them.
#>
param(
  [string]$UnityDir = 'C:\Unity\2017.4.7f1'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$jdk = Get-ChildItem 'C:\Java' -Directory -Filter 'jdk8*' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $jdk) { throw 'JDK 8 not found under C:\Java. Run ./scripts/setup-env.ps1.' }

$src = Join-Path $Root 'unity\Android\bitter\jnibridge\JNIBridge.java'
$out = Join-Path $env:TEMP 'broforce-jnibridge'
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null

# Java 7 bytecode: what the SDK's dx in build-tools 28 handles best.
& "$($jdk.FullName)\bin\javac.exe" -source 1.7 -target 1.7 -nowarn -d $out $src
if ($LASTEXITCODE -ne 0) { throw 'javac failed' }

$variations = Join-Path $UnityDir 'Editor\Data\PlaybackEngines\AndroidPlayer\Variations'
foreach ($jar in Get-ChildItem $variations -Recurse -Filter classes.jar) {
  $orig = "$($jar.FullName).orig"
  if (-not (Test-Path $orig)) { Copy-Item $jar.FullName $orig }
  Copy-Item $orig $jar.FullName -Force
  Push-Location $out
  try {
    & "$($jdk.FullName)\bin\jar.exe" uf $jar.FullName 'bitter/jnibridge/JNIBridge.class' 'bitter/jnibridge/JNIBridge$a.class'
    if ($LASTEXITCODE -ne 0) { throw "jar update failed for $($jar.FullName)" }
  } finally { Pop-Location }
  Write-Host "[jnibridge] patched $($jar.FullName.Substring($variations.Length + 1))"
}
