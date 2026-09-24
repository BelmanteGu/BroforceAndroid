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
