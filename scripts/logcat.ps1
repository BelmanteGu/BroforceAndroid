<#
.SYNOPSIS
  Shows Unity's log from the phone (adb logcat -s Unity), plus crashes.

.EXAMPLE
  ./scripts/logcat.ps1            # follow live
  ./scripts/logcat.ps1 -Dump      # print what's buffered and exit
  ./scripts/logcat.ps1 -Clear     # clear the buffer first, then follow
#>
param(
  [switch]$Dump,
  [switch]$Clear,
  [string]$Serial
)

$adb = @()
if ($Serial) { $adb += @('-s', $Serial) }

if ($Clear) { adb @adb logcat -c }

# Unity: Debug.Log output. CRASH/DEBUG/AndroidRuntime: native and Java crashes.
$filters = @('Unity:V', 'CRASH:E', 'DEBUG:E', 'AndroidRuntime:E', '*:S')
$args2 = @('logcat', '-v', 'time') + $filters
if ($Dump) { $args2 += '-d' }

adb @adb @args2
