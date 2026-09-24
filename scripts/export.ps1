<#
.SYNOPSIS
  Exports your local Broforce install to a Unity project with AssetRipper.

.DESCRIPTION
  Finds the Steam install, downloads AssetRipper into tools/ if needed, runs it
  headless through its HTTP API and exports a Unity project into export/<name>.

  Everything this script produces comes from YOUR copy of the game.
  export/ and tools/ are git-ignored: never commit them.

.PARAMETER ScriptMode
  AssetRipper ScriptExportMode:
    DllExportWithoutRenaming  keep the original DLLs (default, fewest compile errors)
    Decompiled                decompile the game assemblies to C#
    Hybrid, DllExportWithRenaming

.EXAMPLE
  ./scripts/export.ps1
  ./scripts/export.ps1 -ScriptMode Decompiled -Name unity-src
#>
param(
  [string]$GamePath,
  [ValidateSet('DllExportWithoutRenaming', 'DllExportWithRenaming', 'Decompiled', 'Hybrid')]
  [string]$ScriptMode = 'DllExportWithoutRenaming',
  [string]$Name,
  [string]$AssetRipperVersion = '2.0.0',
  [int]$Port = 5123,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Root = Split-Path $PSScriptRoot -Parent
$SteamAppId = '274190'
$UnityVersion = '2017.4.7f1'

function Find-Broforce {
  $steam = $null
  try { $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath } catch {}
  if (-not $steam) { $steam = 'C:\Program Files (x86)\Steam' }
  $steam = $steam -replace '/', '\'

  $libraries = @($steam)
  $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
  if (Test-Path $vdf) {
    foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
      $libraries += $m.Groups[1].Value -replace '\\\\', '\'
    }
  }
  foreach ($lib in ($libraries | Select-Object -Unique)) {
    $manifest = Join-Path $lib "steamapps\appmanifest_$SteamAppId.acf"
    if (Test-Path $manifest) {
      $dir = [regex]::Match((Get-Content $manifest -Raw), '"installdir"\s+"([^"]+)"').Groups[1].Value
      $path = Join-Path $lib "steamapps\common\$dir"
      if (Test-Path "$path\Broforce_beta_Data") { return $path }
    }
  }
  return $null
}

function Get-AssetRipper {
  $exe = Join-Path $Root 'tools\AssetRipper\AssetRipper.GUI.Free.exe'
  if (Test-Path $exe) { return $exe }
  Write-Host "[download] AssetRipper $AssetRipperVersion"
  $zip = Join-Path $Root 'tools\AssetRipper.zip'
  New-Item -ItemType Directory -Force (Split-Path $zip) | Out-Null
  Invoke-WebRequest "https://github.com/AssetRipper/AssetRipper/releases/download/$AssetRipperVersion/AssetRipper_win_x64.zip" -OutFile $zip -UseBasicParsing
  Expand-Archive $zip -DestinationPath (Split-Path $exe) -Force
  Remove-Item $zip
  return $exe
}

# Invoke-WebRequest throws on the 302 that AssetRipper returns after long operations.
function Invoke-Post($url, $body, $timeout = 1800) {
  try {
    Invoke-WebRequest $url -Method Post -Body $body -UseBasicParsing -MaximumRedirection 0 -TimeoutSec $timeout -ErrorAction Stop | Out-Null
  } catch {
    $status = $null
    if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
    if ($status -and $status -ne 302) { throw }
  }
}

# --- Inputs ---
if (-not $GamePath) { $GamePath = Find-Broforce }
if (-not $GamePath -or -not (Test-Path "$GamePath\Broforce_beta_Data")) {
  throw 'Broforce install not found. Pass -GamePath "<folder containing Broforce_beta.exe>".'
}
if (-not $Name) { $Name = if ($ScriptMode -eq 'Decompiled') { 'unity-src' } else { 'unity-dll' } }
$OutDir = Join-Path $Root "export\$Name"
if ((Test-Path $OutDir) -and (Get-ChildItem $OutDir -Force | Select-Object -First 1)) {
  if (-not $Force) { throw "$OutDir is not empty. Use -Force to overwrite." }
  Remove-Item $OutDir -Recurse -Force
}
New-Item -ItemType Directory -Force $OutDir | Out-Null

Write-Host "Game:        $GamePath"
Write-Host "Script mode: $ScriptMode"
Write-Host "Output:      $OutDir"

# --- Run AssetRipper headless ---
$exe = Get-AssetRipper
$log = Join-Path $Root "export\$Name.assetripper.log"
$proc = Start-Process $exe -ArgumentList '--headless', '--port', $Port, '--log-path', "`"$log`"" -PassThru -WindowStyle Hidden
$base = "http://localhost:$Port"
try {
  # Probe the TCP port instead of HTTP: timed-out HTTP requests hold on to
  # Windows PowerShell's small per-host connection pool and block later calls.
  $ready = $false
  for ($i = 0; $i -lt 120 -and -not $ready; $i++) {
    Start-Sleep -Milliseconds 500
    if ($proc.HasExited) { throw "AssetRipper exited early, see $log" }
    $tcp = New-Object Net.Sockets.TcpClient
    try { $tcp.Connect('127.0.0.1', $Port); $ready = $true } catch {} finally { $tcp.Close() }
  }
  if (-not $ready) { throw "AssetRipper did not start on port $Port" }
  Start-Sleep -Seconds 2
  $base = "http://127.0.0.1:$Port"

  # The settings form resets any checkbox that is not sent, so always send the full set.
  # Checked checkboxes are sent with an empty value.
  $settings = @{
    DefaultVersion                 = '0.0.0a0'
    TargetVersion                  = '0.0.0a0'
    BundledAssetsExportMode        = 'DirectExport'
    ScriptContentLevel             = 'Level2'
    AudioExportFormat              = 'Default'
    ImageExportFormat              = 'Png'
    LightmapTextureExportFormat    = 'Yaml'
    SpriteExportMode               = 'Yaml'
    ShaderExportMode               = 'Dummy'   # decompilation is a paid feature; PC shaders are DX bytecode anyway
    TextExportMode                 = 'Parse'
    ScriptLanguageVersion          = 'AutoSafe'
    ScriptExportMode               = $ScriptMode
    PreferOriginalTextureExtension = ''
  }
  Invoke-Post "$base/Settings/Update" $settings 30

  $t = Get-Date
  Write-Host '[load] reading game files...'
  Invoke-Post "$base/LoadFolder" @{ Path = $GamePath }
  Write-Host ('[load] done in {0:N0}s' -f ((Get-Date) - $t).TotalSeconds)

  $t = Get-Date
  Write-Host '[export] writing Unity project...'
  Invoke-Post "$base/Export/UnityProject" @{ Path = $OutDir }
  Write-Host ('[export] done in {0:N0}s' -f ((Get-Date) - $t).TotalSeconds)
} finally {
  if (-not $proc.HasExited) { Stop-Process $proc -Force }
}

$project = Join-Path $OutDir 'ExportedProject'
if (-not (Test-Path "$project\Assets")) { throw "Export failed, see $log" }

# AssetRipper writes a generic 2017.4 version; pin the game's exact version.
$versionFile = Join-Path $project 'ProjectSettings\ProjectVersion.txt'
Set-Content $versionFile "m_EditorVersion: $UnityVersion" -Encoding ascii

$sizeMb = (Get-ChildItem $project -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
Write-Host ''
Write-Host ('Unity project: {0} ({1:N0} MB)' -f $project, $sizeMb)
Write-Host "Log:           $log"
