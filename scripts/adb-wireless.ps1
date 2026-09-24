<#
.SYNOPSIS
  Connects adb to the phone over Wi-Fi, so the USB-C port stays free for a wired gamepad.

.DESCRIPTION
  Two ways to connect:

  1. Pairing (Android 11+, recommended). On the phone:
     Settings > Developer options > Wireless debugging > Pair device with pairing code.
       ./scripts/adb-wireless.ps1 -Pair 192.168.0.10:37123 -Code 123456
     Then connect with the address shown on the Wireless debugging screen
     (the port is different from the pairing port):
       ./scripts/adb-wireless.ps1 -Connect 192.168.0.10:41234

  2. Legacy tcpip mode, while the phone is still plugged in over USB:
       ./scripts/adb-wireless.ps1 -Tcpip
     Switches adbd to TCP port 5555, finds the phone's Wi-Fi IP and connects.
     Lasts until the phone reboots. Undo with: adb usb
#>
param(
  [string]$Pair,
  [string]$Code,
  [string]$Connect,
  [switch]$Tcpip,
  [int]$Port = 5555
)

$ErrorActionPreference = 'Stop'

if ($Pair) {
  if (-not $Code) { throw '-Pair needs -Code (the 6-digit pairing code shown on the phone)' }
  adb pair $Pair $Code
  Write-Host 'Paired. Now run with -Connect <ip:port> from the Wireless debugging screen.'
  return
}

if ($Connect) {
  adb connect $Connect
  adb devices -l
  return
}

if ($Tcpip) {
  $usb = adb devices | Select-String '\tdevice$' | Where-Object { $_ -notmatch ':\d+\s' }
  if (-not $usb) { throw 'No USB device found. Plug the phone in first, or use -Pair/-Connect.' }
  $serial = ($usb[0] -split '\s')[0]

  $addr = adb -s $serial shell ip -f inet addr show wlan0
  $ip = [regex]::Match(($addr -join "`n"), 'inet (\d+\.\d+\.\d+\.\d+)').Groups[1].Value
  if (-not $ip) {
    $route = adb -s $serial shell ip route
    $ip = [regex]::Match(($route -join "`n"), 'wlan0.*?src (\d+\.\d+\.\d+\.\d+)').Groups[1].Value
  }
  if (-not $ip) { throw 'Could not find the phone Wi-Fi IP. Turn Wi-Fi on (same network as this PC).' }

  adb -s $serial tcpip $Port | Out-Null
  Start-Sleep -Seconds 2
  adb connect "${ip}:$Port"
  Write-Host "Connected to ${ip}:$Port. You can unplug the USB cable now."
  return
}

Get-Help $MyInvocation.MyCommand.Path -Detailed
