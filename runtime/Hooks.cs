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
        /// Replaces Object.DestroyImmediate(obj) in [ExecuteInEditMode] game code (e.g.
        /// SpriteBase.Awake). The shipped DLL is the player build, so its edit-mode guards
        /// were compiled out: in the Editor, during a build, it would destroy mesh assets
        /// and the build fails ("Destroying assets is not permitted"). Same behavior in-game.
        /// </summary>
        public static void DestroyImmediateAtRuntime(Object obj)
        {
            if (Application.isPlaying)
                Object.DestroyImmediate(obj);
        }

        /// <summary>
        /// Guards the game's own OnRenderImage effects that we don't port (Amplify Color
        /// grading: its hidden shaders are still placeholders and it blacks out the screen).
        /// Returns true when it already copied source to destination and the effect must skip.
        /// </summary>
        public static bool SkipImageEffect(RenderTexture source, RenderTexture destination)
        {
            if (ImageEffectsAllowed()) return false;
            Graphics.Blit(source, destination);
            return true;
        }

        /// <summary>
        /// Replaces target.LoadRawTextureData(source.GetRawTextureData()) in
        /// SaveSlotsMenu.SaveDefaultThumbnail. That byte copy only works when both textures
        /// share a format; on Android the source is ETC2-compressed and Unity throws, which
        /// aborted starting a new campaign. Drawing through a RenderTexture works for any format.
        /// </summary>
        public static void CopyTexture(Texture2D target, Texture2D source)
        {
            RenderTexture rt = RenderTexture.GetTemporary(target.width, target.height, 0);
            RenderTexture previous = RenderTexture.active;
            Graphics.Blit(source, rt);
            RenderTexture.active = rt;
            target.ReadPixels(new Rect(0, 0, target.width, target.height), 0, 0);
            target.Apply();
            RenderTexture.active = previous;
            RenderTexture.ReleaseTemporary(rt);
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
            LogRewiredState();
        }

        /// <summary>
        /// Called first thing in Rewired's InputManager_Base.HandleException. The game ships
        /// with Rewired's own logger turned off, so without this an initialization failure
        /// (which disables all input) leaves no trace in the log.
        /// </summary>
        public static void LogRewiredException(string where, System.Exception exception)
        {
            Debug.LogError("[BroforceAndroid] Rewired exception during " + where + ": " + exception);
        }

        static float nextTick;
        static string lastScene;

        /// <summary>Every camera in the scene, enabled or not, with where it draws.</summary>
        static void DumpCameras(string scene)
        {
            Debug.Log("[BroforceAndroid] scene " + scene + " screen=" + Screen.width + "x" + Screen.height
                + " dpi=" + Screen.dpi + " safeArea=" + Screen.safeArea);
            foreach (Object o in Resources.FindObjectsOfTypeAll(typeof(Camera)))
            {
                Camera c = (Camera)o;
                if (!c.gameObject.scene.IsValid()) continue;   // prefabs/assets, not in a scene
                Debug.Log("[BroforceAndroid]   cam '" + c.name + "' enabled=" + c.enabled + " active=" + c.gameObject.activeInHierarchy
                    + " depth=" + c.depth + " rect=" + c.rect + " pixelRect=" + c.pixelRect
                    + " ortho=" + c.orthographic + "/" + c.orthographicSize + " pos=" + c.transform.position
                    + " RT=" + (c.targetTexture != null ? c.targetTexture.width + "x" + c.targetTexture.height : "none")
                    + " parent=" + (c.transform.parent != null ? c.transform.parent.name : "-"));
                string comps = "";
                foreach (Behaviour b in c.GetComponents<Behaviour>())
                    if (b != null && !(b is Camera)) comps += b.GetType().Name + (b.enabled ? "" : "(off)") + " ";
                Debug.Log("[BroforceAndroid]     components: " + comps);
            }

            // The biggest visible renderers: a black screen is either nothing drawing or
            // something big drawing on top.
            var list = new System.Collections.Generic.List<Renderer>();
            foreach (Renderer r in Object.FindObjectsOfType<Renderer>())
                if (r.enabled && r.gameObject.activeInHierarchy && r.isVisible) list.Add(r);
            list.Sort((a, b) => (b.bounds.size.x * b.bounds.size.y).CompareTo(a.bounds.size.x * a.bounds.size.y));
            Debug.Log("[BroforceAndroid]   visible renderers: " + list.Count);
            for (int i = 0; i < list.Count && i < 25; i++)
            {
                Renderer r = list[i];
                Material m = r.sharedMaterial;
                Texture mt = m != null && m.HasProperty("_MainTex") ? m.mainTexture : null;
                Texture2D mt2 = mt as Texture2D;
                Debug.Log("[BroforceAndroid]   rend '" + r.name + "' " + r.GetType().Name
                    + " mat=" + (m != null ? m.name : "none")
                    + " tex=" + (mt != null ? mt.name + (mt2 != null ? "/" + mt2.format : "") : "none")
                    + " shader=" + (m != null && m.shader != null ? m.shader.name + (m.shader.isSupported ? "" : " (UNSUPPORTED)") : "none")
                    + " queue=" + (m != null ? m.renderQueue : -1) + " center=" + r.bounds.center + " size=" + r.bounds.size
                    + " layer=" + LayerMask.LayerToName(r.gameObject.layer) + " sort=" + r.sortingOrder);
            }
        }

        /// <summary>
        /// Called every frame from Utility.Platforms.Platform.Update. Every 5 s logs the
        /// active scene, the Fader state and the enabled cameras, which is what you need
        /// to tell a black screen from a stuck scene in a logcat.
        /// </summary>
        public static void Tick()
        {
            string scene = UnityEngine.SceneManagement.SceneManager.GetActiveScene().name;
            if (scene != lastScene && Time.timeSinceLevelLoad > 4f)
            {
                lastScene = scene;
                try { DumpCameras(scene); } catch (System.Exception e) { Debug.Log("[BroforceAndroid] camera dump failed: " + e.Message); }
            }
            if (Time.realtimeSinceStartup < nextTick) return;
            nextTick = Time.realtimeSinceStartup + 5f;
            try
            {
                string fader = "n/a";
                System.Type faderType = System.Type.GetType("Fader, Broforce.Game");
                if (faderType != null)
                {
                    const System.Reflection.BindingFlags all = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Static
                        | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic;
                    System.Reflection.FieldInfo inst = faderType.GetField("instance", all);
                    object f = inst == null ? null : inst.GetValue(null);
                    Component fc = f as Component;
                    if (fc != null)
                    {
                        fader = "active=" + fc.gameObject.activeInHierarchy;
                        foreach (string n in new[] { "fadeToBlack", "fadeFromBlack", "fading", "counter", "fadeSpeed" })
                        {
                            System.Reflection.FieldInfo fi = faderType.GetField(n, all);
                            if (fi != null) fader += " " + n + "=" + fi.GetValue(fi.IsStatic ? null : f);
                        }
                    }
                    else fader = "no instance";
                }
                string cams = "";
                foreach (Camera c in Camera.allCameras)
                    cams += c.name + "(d" + c.depth + (c.targetTexture != null ? ",RT" : "") + ") ";
                Debug.Log("[BroforceAndroid] tick scene=" + UnityEngine.SceneManagement.SceneManager.GetActiveScene().name
                    + " t=" + Time.time.ToString("F0") + " timeScale=" + Time.timeScale + " fader[" + fader + "] cams: " + cams);
            }
            catch (System.Exception e)
            {
                Debug.Log("[BroforceAndroid] tick failed: " + e.Message);
            }
        }

        /// <summary>Rewired state, read by reflection (this assembly doesn't reference Rewired).</summary>
        static void LogRewiredState()
        {
            try
            {
                System.Type reInput = System.Type.GetType("Rewired.ReInput, Rewired_Core");
                if (reInput == null) { Debug.Log("[BroforceAndroid] rewired: ReInput type not found"); return; }
                object ready = reInput.GetProperty("isReady").GetValue(null, null);
                object players = reInput.GetProperty("players").GetValue(null, null);
                object count = players == null ? null : players.GetType().GetProperty("playerCount").GetValue(players, null);
                Debug.Log("[BroforceAndroid] rewired: isReady=" + ready + " players=" + (players == null ? "null" : count.ToString()));

                System.Type managerBase = System.Type.GetType("Rewired.InputManager_Base, Rewired_Core");
                if (managerBase != null)
                {
                    Object[] managers = Object.FindObjectsOfType(managerBase);
                    Debug.Log("[BroforceAndroid] rewired: InputManager instances=" + managers.Length);
                    foreach (Object m in managers)
                    {
                        Behaviour b = m as Behaviour;
                        Debug.Log("[BroforceAndroid] rewired:   " + m.GetType().FullName + " on '" + m.name
                            + "' enabled=" + (b != null && b.enabled) + " activeInHierarchy=" + (b != null && b.gameObject.activeInHierarchy));
                        const System.Reflection.BindingFlags any = System.Reflection.BindingFlags.Instance
                            | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic;
                        foreach (string field in new[] { "initialized", "criticalError", "_controllerDataFiles", "_userData", "_dontDestroyOnLoad", "platform", "editorPlatform", "isEditor" })
                        {
                            System.Reflection.FieldInfo fi = null;
                            for (System.Type t = m.GetType(); t != null && fi == null; t = t.BaseType)
                                fi = t.GetField(field, any);
                            object v = fi == null ? "<no field>" : fi.GetValue(m);
                            Debug.Log("[BroforceAndroid] rewired:     " + field + " = " + (v == null ? "null" : v.ToString()));
                        }
                    }
                }
            }
            catch (System.Exception e)
            {
                Debug.Log("[BroforceAndroid] rewired: inspection failed: " + e);
            }
        }
    }
}
