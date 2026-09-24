# Debugging on the device

With a **wired** gamepad the phone's only USB-C port is taken, so adb has to go over Wi-Fi. The phone and the PC must be on the same network.

## Connect over Wi-Fi

**Option A: Wireless debugging (Android 11+, recommended).** Survives cable changes and doesn't need USB at all.

1. On the phone: **Settings → Developer options → Wireless debugging → On**
2. Tap **Pair device with pairing code**, then run:
   ```powershell
   ./scripts/adb-wireless.ps1 -Pair <ip>:<pairing-port> -Code <6-digit code>
   ```
3. Back on the Wireless debugging screen, use the **IP address & port** shown there (a different port):
   ```powershell
   ./scripts/adb-wireless.ps1 -Connect <ip>:<port>
   ```

Pairing is needed only once per PC. After that, `-Connect` is enough. The port changes whenever Wireless debugging is toggled.

**Option B: tcpip mode.** Quicker if the phone is plugged in anyway:

```powershell
./scripts/adb-wireless.ps1 -Tcpip   # while connected over USB; then unplug
```

It lasts until the phone reboots. `adb usb` switches back.

## Install, launch, read logs

```powershell
./scripts/install.ps1 -Log          # newest APK under build/, launch it, follow the log
./scripts/logcat.ps1                # follow Unity + crash output
./scripts/logcat.ps1 -Dump          # print the buffer and exit
```

`logcat.ps1` shows the `Unity` tag (all `Debug.Log` output and managed exceptions) plus native/Java crash tags (`CRASH`, `DEBUG`, `AndroidRuntime`).

If more than one device is connected (e.g. USB and Wi-Fi at once), pass `-Serial <id>` from `adb devices`.

## Reference device

Galaxy S23 (Android 16). Enabling Developer options: **Settings → About phone → Software information → tap Build number 7 times**.
