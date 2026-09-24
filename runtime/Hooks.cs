using System.IO;
using UnityEngine;

namespace BroforceAndroid
{
    /// <summary>
    /// Entry points that patched game methods call into. Keep signatures stable:
    /// the patcher looks these up by name.
    /// </summary>
    public static class Hooks
    {
        /// <summary>
        /// Replaces FileIO.GetPlatformDataPath. The game passes paths relative to the
        /// working directory ("Saves/", "Levels/"), which is "/" on Android.
        /// </summary>
        public static string GetPlatformDataPath(string path)
        {
            if (string.IsNullOrEmpty(path) || Path.IsPathRooted(path))
                return path;
            return Path.Combine(Application.persistentDataPath, path);
        }

        // Values of Rewired.Platforms.Platform in the shipped Rewired_Core.
        const int RewiredPlatformWindows = 1;
        const int RewiredPlatformAndroid = 7;

        /// <summary>
        /// Replaces the hardcoded Platform.Windows in Rewired.InputManager.DetectPlatform.
        /// Still reports Windows in the Editor so the PC workflow keeps working.
        /// </summary>
        public static int GetRewiredPlatform()
        {
            return Application.platform == RuntimePlatform.Android
                ? RewiredPlatformAndroid
                : RewiredPlatformWindows;
        }

        /// <summary>
        /// Guards PostEffectsBase.CheckSupport: the Standard Assets image effects stay on
        /// in the Editor but disable themselves on Android.
        /// </summary>
        public static bool ImageEffectsAllowed()
        {
            return Application.platform != RuntimePlatform.Android;
        }

        /// <summary>
        /// Called at the start of Startup.Start (the first scene). Logs what we need when
        /// reading `adb logcat -s Unity` from a bug report.
        /// </summary>
        public static void OnStartup()
        {
            if (Application.platform == RuntimePlatform.Android)
            {
                // Unity caps Android at 30 FPS unless targetFrameRate is set, and the game
                // never sets it (on PC it relies on vsync).
                Application.targetFrameRate = 60;
                // Gamepad-only play: nothing touches the screen, so don't let it dim.
                Screen.sleepTimeout = SleepTimeout.NeverSleep;
            }

            Debug.Log("[BroforceAndroid] " + Application.platform + " | " + SystemInfo.deviceModel
                + " | " + SystemInfo.operatingSystem + " | " + SystemInfo.graphicsDeviceType
                + " " + SystemInfo.graphicsDeviceVersion + " | " + Screen.width + "x" + Screen.height
                + " | RAM " + SystemInfo.systemMemorySize + " MB");
            Debug.Log("[BroforceAndroid] persistentDataPath: " + Application.persistentDataPath);
            string[] pads = Input.GetJoystickNames();
            Debug.Log("[BroforceAndroid] joysticks (" + pads.Length + "): " + string.Join(" | ", pads));
        }
    }
}
