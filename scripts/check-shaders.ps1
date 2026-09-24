<#
.SYNOPSIS
  Compiles every shader in shaders/ for Android in a small throwaway Unity project.

.DESCRIPTION
  Creates export/shadertest with the shaders, one material each and an empty scene,
  then builds an Android APK. The build compiles every variant for GLES3/GLES2, so
  shader errors show up in minutes instead of after a full game build. It also checks
  the Android toolchain (SDK, JDK, APK packaging).

  Errors are printed at the end; the full log is export/shadertest.log.
#>
param(
  [string]$Unity = 'C:\Unity\2017.4.7f1\Editor\Unity.exe'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$project = Join-Path $Root 'export\shadertest'
$log = Join-Path $Root 'export\shadertest.log'

New-Item -ItemType Directory -Force "$project\Assets\Shaders", "$project\Assets\Editor" | Out-Null
Get-ChildItem "$project\Assets\Shaders" -Filter *.shader -ErrorAction SilentlyContinue | Remove-Item -Force
Copy-Item (Join-Path $Root 'shaders\*.shader') "$project\Assets\Shaders\" -Force
Copy-Item (Join-Path $Root 'unity\ShaderCheck\ShaderCheck.cs') "$project\Assets\Editor\" -Force
if (Test-Path "$project\Assets\Resources") { Remove-Item "$project\Assets\Resources" -Recurse -Force }

# The SDK tools Unity calls (avdmanager, sdkmanager) run on JAVA_HOME / PATH, not on
# Unity's JDK preference, and they break on JDK 9+ (javax.xml.bind is gone).
$jdk = Get-ChildItem 'C:\Java' -Directory -Filter 'jdk8*' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $jdk) { throw 'JDK 8 not found under C:\Java. Run ./scripts/setup-env.ps1.' }
$env:JAVA_HOME = $jdk.FullName
$env:Path = "$($jdk.FullName)\bin;$env:Path"

Write-Host "[unity] building shader test project (log: $log)"
$t = Get-Date
$p = Start-Process $Unity -PassThru -Wait -WindowStyle Hidden -ArgumentList @(
  '-batchmode', '-nographics', '-buildTarget', 'Android',
  '-projectPath', "`"$project`"",
  '-executeMethod', 'ShaderCheck.Run',
  '-logFile', "`"$log`""
)
Write-Host ('[unity] exit {0} in {1:N1} min' -f $p.ExitCode, ((Get-Date) - $t).TotalMinutes)

# Shader compile errors look like: Shader error in 'Name': message at line N (on gles3)
Select-String -Path $log -Pattern "\[ShaderCheck\]|Shader error in|Shader warning in '.*' .*(gles|GLES)" |
  ForEach-Object { $_.Line } | Select-Object -Unique
exit $p.ExitCode
