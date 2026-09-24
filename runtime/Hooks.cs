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
    }
}
