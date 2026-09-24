<#
.SYNOPSIS
  Builds the runtime and the patcher, then patches the exported project's game DLLs.

.DESCRIPTION
  Applies every patch in patcher/Patches.cs to export/<Name>/ExportedProject.
  The original DLLs are backed up to export/<Name>/original-dlls on the first run,
  and every run starts from that backup, so it's safe to run repeatedly.

  Requires the .NET SDK 8 or newer.

.EXAMPLE
  ./scripts/patch.ps1
#>
param(
  [string]$Name = 'unity-dll',
  [string]$GameManagedDir
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$project = Join-Path $Root "export\$Name\ExportedProject"
if (-not (Test-Path $project)) { throw "$project not found. Run ./scripts/export.ps1 first." }

if (-not $GameManagedDir) {
  $GameManagedDir = 'C:\Program Files (x86)\Steam\steamapps\common\Broforce\Broforce_beta_Data\Managed'
}
if (-not (Test-Path "$GameManagedDir\UnityEngine.CoreModule.dll")) {
  throw "Game Managed folder not found. Pass -GameManagedDir '<Broforce>\Broforce_beta_Data\Managed'."
}

# Managed assemblies that nothing on the runtime path references: not reachable from
# Assembly-CSharp/firstpass/UnityScript/Rewired, and no scene, prefab or asset uses
# their scripts (checked by GUID). Windows UI, console SDKs, the PowerInspector runtime
# inspector (debug tool, the only user of Odin/FastReflection) and framework copies
# that Unity provides itself. See #7, #8 and #11.
# XboxOneCommonImport, AlienFXManagedWrapper3.5 and Gif.Components stay: Assembly-CSharp
# references them; their call sites are neutralized by the patcher instead.
$prune = @(
  'Accessibility', 'CommonForms', 'GifComponents', 'Mono.Posix', 'Mono.WebBrowser',
  'System.Configuration', 'System.Drawing', 'System.EnterpriseServices',
  'System.Runtime.CompilerServices.Unsafe', 'System.Runtime.InteropServices',
  'System.Security', 'System.Windows.Forms',
  'Unity.ZombieObjectDetector.Runtime', 'UnityEtx',
  # PowerInspector (Sisus.Newtonsoft.Json stays: Assembly-CSharp uses it)
  'PowerInspector.Runtime', 'Sisus.Attributes', 'Sisus.FastReflection', 'Sisus.OdinSerializer',
  # Xbox One
  'ConsoleUtilsImport', 'DataPlatformImport', 'FriendsImport', 'GameDVRImport', 'GamepadImport',
  'MarketplaceImport', 'MultiplayerImport', 'SmartGlassImport', 'StorageImport',
  'StreamingInstallImport', 'TextSystemsImport', 'UnityPluginLogImport', 'UsersImport', 'XIMImport',
  # PS4
  'SonyNP', 'SonyPS4CommonDialog', 'SonyPS4SavedGames'
)
$plugins = Join-Path $project 'Assets\Plugins'
$removed = Join-Path $Root "export\$Name\removed-plugins"
New-Item -ItemType Directory -Force $removed | Out-Null
$moved = 0
foreach ($asm in $prune) {
  foreach ($file in "$asm.dll", "$asm.dll.meta") {
    $src = Join-Path $plugins $file
    if (Test-Path $src) { Move-Item $src (Join-Path $removed $file) -Force; $moved++ }
  }
}
Write-Host "[prune] moved $moved files to $removed ($($prune.Count) assemblies)"

# Original assemblies: AssetRipper re-writes the game DLLs it exports, and the result is
# not faithful: Rewired_Core then fails at runtime with a TypeLoadException in
# Rewired.Player's constructor, which disables all input. Use the game's own DLLs instead
# (the .meta files, and so the GUIDs scenes reference, stay the exported ones).
$backupDir = Join-Path $Root "export\$Name\original-dlls"
$restored = 0
foreach ($dir in @($plugins, $backupDir)) {
  foreach ($dll in Get-ChildItem $dir -Filter *.dll -ErrorAction SilentlyContinue) {
    $original = Join-Path $GameManagedDir $dll.Name
    if ((Test-Path $original) -and ((Get-FileHash $original).Hash -ne (Get-FileHash $dll.FullName).Hash)) {
      Copy-Item $original $dll.FullName -Force
      $restored++
    }
  }
}
Write-Host "[originals] replaced $restored AssetRipper-rewritten DLL(s) with the game's originals"

# WAV headers: AssetRipper writes about half of the clips with the RIFF and data chunk
# sizes left at 0 (a streaming-style header). The samples are fine, but Unity's FSBTool
# refuses them ("Failed decoding audio clip"), leaving voices and effects silent.
# Fill in both sizes for canonical 44-byte PCM headers.
$fixedWavs = 0
foreach ($wav in Get-ChildItem (Join-Path $project 'Assets') -Recurse -Filter *.wav) {
  $fs = [IO.File]::Open($wav.FullName, 'Open', 'ReadWrite')
  try {
    $h = New-Object byte[] 44
    if ($fs.Read($h, 0, 44) -lt 44) { continue }
    $isCanonical = [Text.Encoding]::ASCII.GetString($h, 0, 4) -eq 'RIFF' -and
      [Text.Encoding]::ASCII.GetString($h, 8, 4) -eq 'WAVE' -and
      [BitConverter]::ToUInt32($h, 16) -eq 16 -and
      [Text.Encoding]::ASCII.GetString($h, 36, 4) -eq 'data'
    if (-not $isCanonical) { continue }
    if ([BitConverter]::ToUInt32($h, 4) -ne 0 -and [BitConverter]::ToUInt32($h, 40) -ne 0) { continue }
    $fs.Position = 4;  $fs.Write([BitConverter]::GetBytes([uint32]($fs.Length - 8)), 0, 4)
    $fs.Position = 40; $fs.Write([BitConverter]::GetBytes([uint32]($fs.Length - 44)), 0, 4)
    $fixedWavs++
  } finally { $fs.Dispose() }
}
Write-Host "[audio] fixed $fixedWavs WAV header(s)"

# Rewritten shaders (shaders/*.shader, see docs/shaders.md). Each replaces every
# placeholder with the same Shader "name" (most shaders are exported twice: once from
# the main data files, once from the bundles), keeping the placeholders' .meta so
# materials still point at them by GUID.
$exported = @{}
foreach ($f in Get-ChildItem (Join-Path $project 'Assets') -Recurse -Filter *.shader) {
  $m = Select-String -LiteralPath $f.FullName -Pattern '^\s*Shader\s+"([^"]+)"' | Select-Object -First 1
  if ($m) { $exported[$m.Matches[0].Groups[1].Value] += @($f.FullName) }
}
$replaced = 0
foreach ($f in Get-ChildItem (Join-Path $Root 'shaders') -Filter *.shader) {
  $m = Select-String -LiteralPath $f.FullName -Pattern '^\s*Shader\s+"([^"]+)"' | Select-Object -First 1
  $name = $m.Matches[0].Groups[1].Value
  if (-not $exported.ContainsKey($name)) { throw "No exported shader named '$name' for $($f.Name)" }
  foreach ($target in $exported[$name]) {
    Copy-Item -LiteralPath $f.FullName -Destination $target -Force
    $replaced++
  }
}
Write-Host "[shaders] replaced $replaced placeholder file(s)"

Write-Host '[build] runtime'
dotnet build (Join-Path $Root 'runtime') -c Release -nologo -v q "-p:GameManagedDir=$GameManagedDir"
if ($LASTEXITCODE -ne 0) { throw 'runtime build failed' }

Write-Host '[build] patcher'
dotnet build (Join-Path $Root 'patcher') -c Release -nologo -v q
if ($LASTEXITCODE -ne 0) { throw 'patcher build failed' }

Write-Host '[patch]'
$runtimeDll = Join-Path $Root 'runtime\bin\Release\net35\BroforceAndroid.Runtime.dll'
dotnet run --project (Join-Path $Root 'patcher') -c Release --no-build -- $project $runtimeDll $GameManagedDir
if ($LASTEXITCODE -ne 0) { throw 'patching failed' }
