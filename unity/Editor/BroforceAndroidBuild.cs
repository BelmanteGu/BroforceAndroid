// Editor automation for the Android port. Copied into the exported project by
// scripts/patch.ps1 (Assets/Editor/BroforceAndroid/). Unity 2017.4 compiles editor
// scripts with C# 4 on the .NET 3.5 profile, so keep the syntax old-fashioned.
//
// Batch mode entry points (-executeMethod):
//   BroforceAndroid.Build.ConfigureAndroid   player settings, SDK/JDK paths, switch platform
//   BroforceAndroid.Build.BuildBundles       rebuild the game's AssetBundles for the active target
//   BroforceAndroid.Build.BuildApk           bundles + APK into <repo>/build/
//
// Optional command line arguments:
//   -sdkRoot <path>   Android SDK (default C:\Android\sdk-legacy)
//   -jdkPath <path>   JDK 8
//   -apkPath <path>   output APK

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;

namespace BroforceAndroid
{
    public static class Build
    {
        const string BundleId = "io.github.belmantegu.broforceandroid";
        const string BundleExtension = ".assetbundle";

        // Scene bundles: every .unity under Assets/BundleAssets/<Folder>/ goes into the
        // bundle named after the folder. AssetRipper already restores assetBundleName
        // for the other (asset) bundles from the original bundles' containers.
        static readonly string[] SceneBundleFolders =
        {
            "ScenesIntro", "ScenesMain", "ScenesMenus", "ScenesMissions", "ScenesOther"
        };

        // Bundles the game expects (GameSystems.prefab). Used to verify the build.
        static readonly string[] ExpectedBundles =
        {
            "scenesintroshared", "scenesintro", "scenesshared", "scenesmenus", "sharedtextures",
            "sharedsounds", "sharedassets", "networkobjects", "expendabros", "themeholders",
            "scenesmain", "scenesmissions", "levels", "cutscenes", "scenesother", "chunks"
        };

        static string ProjectDir { get { return Path.GetDirectoryName(Application.dataPath); } }
        static string RepoDir { get { return Path.GetFullPath(Path.Combine(ProjectDir, "../../..")); } }
        static string StreamingAssets { get { return Path.Combine(Application.dataPath, "StreamingAssets"); } }

        // ------------------------------------------------------------------ Android

        [MenuItem("BroforceAndroid/Configure Android")]
        public static void ConfigureAndroid()
        {
            EditorPrefs.SetString("AndroidSdkRoot", Arg("-sdkRoot", @"C:\Android\sdk-legacy"));
            string jdk = Arg("-jdkPath", FindJdk8());
            if (!string.IsNullOrEmpty(jdk)) EditorPrefs.SetString("JdkPath", jdk);

            PlayerSettings.companyName = "BroforceAndroid";
            PlayerSettings.productName = "Broforce";
            PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.Android, BundleId);

            // Unity 2017.4 + Mono only produces 32-bit ARM.
            PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.Mono2x);
            PlayerSettings.Android.targetDevice = AndroidTargetDevice.ARMv7;
            PlayerSettings.strippingLevel = StrippingLevel.Disabled;

            // GLES3 only: every device that can run this has it, and the shaders we leave
            // as AssetRipper placeholders (e.g. Amplify Color's) don't compile for GLES2.
            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.Android, false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android,
                new[] { UnityEngine.Rendering.GraphicsDeviceType.OpenGLES3 });

            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel19;
            // Android 14+ refuses to install apps targeting < 23. 28 is what sdk-legacy ships.
            PlayerSettings.Android.targetSdkVersion = (AndroidSdkVersions)28;

            PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = true;
            // Unity 2017 caps the aspect ratio at 2.1 (letterboxing a 19.5:9 S23). The
            // game's cameras adapt to any width, so allow up to 21:9 and beyond.
            var player = new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/ProjectSettings.asset")[0]);
            player.FindProperty("androidSupportedAspectRatio").intValue = 2;   // Custom
            player.FindProperty("androidMaxAspectRatio").floatValue = 2.4f;
            player.ApplyModifiedPropertiesWithoutUndo();
            PlayerSettings.Android.forceSDCardPermission = false;
            PlayerSettings.Android.forceInternetPermission = false;
            PlayerSettings.Android.androidIsGame = true;
            // Gamepad only: don't require a touchscreen, so the game isn't hidden on TV boxes.
            PlayerSettings.Android.androidTVCompatibility = true;

            // "HW Statistics" makes the player look up the Google advertising ID by binding
            // to Play services through Unity 2017's JNIBridge, which crashes on Android 16
            // (NoSuchMethodError: ServiceConnection.onServiceConnected(..., IBinderSession)).
            // The property is internal in 2017.4 (the UI only exposes it to paid licenses).
            var submitAnalytics = typeof(PlayerSettings).GetProperty("submitAnalytics",
                System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.NonPublic);
            if (submitAnalytics != null) submitAnalytics.SetValue(null, false, null);
            Debug.Log("[BroforceAndroid] HW statistics: " + (submitAnalytics != null ? submitAnalytics.GetValue(null, null) : "n/a"));

            EditorUserBuildSettings.androidBuildSubtarget = MobileTextureSubtarget.ETC2;
            EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Internal;

            if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.Android)
            {
                Debug.Log("[BroforceAndroid] Switching platform to Android (reimports textures)...");
                EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);
            }
            AssetDatabase.SaveAssets();
            Debug.Log("[BroforceAndroid] Android configured.");
        }

        // ------------------------------------------------------------------ Bundles

        [MenuItem("BroforceAndroid/Build Bundles")]
        public static void BuildBundles()
        {
            ConvertLightmaps();
            FixBlankTextures();
            AssignSceneBundles();

            string[] names = AssetDatabase.GetAllAssetBundleNames();
            string[] missing = ExpectedBundles.Where(b => !names.Contains(b)).ToArray();
            if (missing.Length > 0)
                Fail("No assets assigned to bundle(s): " + string.Join(", ", missing));

            BuildTarget target = EditorUserBuildSettings.activeBuildTarget;
            string outDir = Path.Combine(ProjectDir, "BundleBuild/" + target);
            Directory.CreateDirectory(outDir);

            Debug.Log("[BroforceAndroid] Building " + names.Length + " bundles for " + target + "...");
            // LZ4 (chunk based) so AssetBundle.LoadFromFile works straight from the APK.
            // Always a full rebuild: Unity's incremental check hashes the assets, not the
            // scripts' assembly names, so after the patcher renames assemblies it would
            // keep scenes that point at the old names ("referenced script is missing").
            AssetBundleManifest manifest = BuildPipeline.BuildAssetBundles(outDir,
                BuildAssetBundleOptions.ChunkBasedCompression | BuildAssetBundleOptions.ForceRebuildAssetBundle, target);
            if (manifest == null) Fail("BuildAssetBundles failed");

            // The game loads "<streamingAssets>/<name>.assetbundle".
            Directory.CreateDirectory(StreamingAssets);
            foreach (string name in manifest.GetAllAssetBundles())
            {
                string dst = Path.Combine(StreamingAssets, name + BundleExtension);
                File.Copy(Path.Combine(outDir, name), dst, true);
                Debug.Log(string.Format("[BroforceAndroid]   {0}{1} {2:N1} MB", name, BundleExtension,
                    new FileInfo(dst).Length / 1048576.0));
            }
            AssetDatabase.Refresh();
            Debug.Log("[BroforceAndroid] Bundles written to " + StreamingAssets);
        }

        // AssetRipper exports baked lightmaps as native Texture2D assets that keep the PC
        // format (DXT5 holding RGBM). Android can't use that, and the lit scenes (the
        // WorldMap3D globe) render black. Decode each one to an HDR EXR under the same GUID,
        // imported as a Lightmap, so Unity re-encodes it for the target platform.
        const float RgbmRange = 5f;   // Unity's RGBM range in gamma colour space

        static void ConvertLightmaps()
        {
            string assets = Path.Combine(ProjectDir, "Assets");
            var found = Directory.GetFiles(assets, "Lightmap-*.texture2D", SearchOption.AllDirectories)
                .Concat(Directory.GetFiles(assets, "Lightmap-*.asset", SearchOption.AllDirectories));
            foreach (string exported in found)
            {
                // Unity 2017 doesn't import the ".texture2D" extension; ".asset" it does.
                string file = Path.ChangeExtension(exported, ".asset");
                if (file != exported)
                {
                    File.Move(exported, file);
                    File.Move(exported + ".meta", file + ".meta");
                    AssetDatabase.Refresh();
                }
                string path = "Assets" + file.Substring(assets.Length).Replace('\\', '/');
                string guid = AssetDatabase.AssetPathToGUID(path);
                var src = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
                if (src == null || string.IsNullOrEmpty(guid)) { Debug.Log("[BroforceAndroid] Lightmap not loadable: " + path); continue; }

                // Blit decompresses on the editor's GPU; linear read keeps the raw RGBM bytes.
                var rt = RenderTexture.GetTemporary(src.width, src.height, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
                Graphics.Blit(src, rt);
                var raw = new Texture2D(src.width, src.height, TextureFormat.RGBA32, false, true);
                RenderTexture prev = RenderTexture.active;
                RenderTexture.active = rt;
                raw.ReadPixels(new Rect(0, 0, src.width, src.height), 0, 0);
                RenderTexture.active = prev;
                RenderTexture.ReleaseTemporary(rt);

                Color[] px = raw.GetPixels();
                for (int i = 0; i < px.Length; i++)
                {
                    float m = px[i].a * RgbmRange;
                    px[i] = new Color(px[i].r * m, px[i].g * m, px[i].b * m, 1f);
                }
                var hdr = new Texture2D(src.width, src.height, TextureFormat.RGBAHalf, false, true);
                hdr.SetPixels(px);
                byte[] exr = hdr.EncodeToEXR(Texture2D.EXRFlags.CompressZIP);
                UnityEngine.Object.DestroyImmediate(raw);
                UnityEngine.Object.DestroyImmediate(hdr);

                // Same GUID, new importer: references (type 2 native -> type 3 imported) still resolve.
                string full = Path.Combine(ProjectDir, path);
                string exrPath = Path.ChangeExtension(path, ".exr");
                File.WriteAllBytes(Path.Combine(ProjectDir, exrPath), exr);
                File.WriteAllText(Path.Combine(ProjectDir, exrPath) + ".meta",
                    "fileFormatVersion: 2\nguid: " + guid + "\nTextureImporter:\n  textureType: 6\n");
                File.Delete(full);
                File.Delete(full + ".meta");
                foreach (string lighting in Directory.GetFiles(Path.GetDirectoryName(full), "LightingData*.asset"))
                {
                    string text = File.ReadAllText(lighting);
                    string fixedText = text.Replace("guid: " + guid + ", type: 2", "guid: " + guid + ", type: 3");
                    if (fixedText != text) File.WriteAllText(lighting, fixedText);
                }
                AssetDatabase.Refresh();

                var importer = (TextureImporter)AssetImporter.GetAtPath(exrPath);
                importer.textureType = TextureImporterType.Lightmap;
                importer.mipmapEnabled = true;
                importer.wrapMode = TextureWrapMode.Clamp;
                importer.SaveAndReimport();
                Debug.Log("[BroforceAndroid] Lightmap " + path + " -> " + exrPath);
            }
        }

        // Some textures are fully transparent in the game (the jungle's ParaCloud1-3):
        // invisible on PC, but ETC2-compressed on Android they draw as white rectangles.
        // Keep those uncompressed. Blank PNGs are tiny, so only small files are checked.
        static void FixBlankTextures()
        {
            string assets = Path.Combine(ProjectDir, "Assets");
            int count = 0;
            foreach (string file in Directory.GetFiles(assets, "*.png", SearchOption.AllDirectories))
            {
                if (new FileInfo(file).Length > 4096) continue;
                var probe = new Texture2D(2, 2);
                bool blank = probe.LoadImage(File.ReadAllBytes(file)) && probe.GetPixels32().All(p => p.a == 0);
                UnityEngine.Object.DestroyImmediate(probe);
                if (!blank) continue;

                string path = "Assets" + file.Substring(assets.Length).Replace('\\', '/');
                var importer = AssetImporter.GetAtPath(path) as TextureImporter;
                if (importer == null) continue;
                TextureImporterPlatformSettings android = importer.GetPlatformTextureSettings("Android");
                if (android.overridden && android.format == TextureImporterFormat.RGBA32) continue;
                android.overridden = true;
                android.format = TextureImporterFormat.RGBA32;
                importer.SetPlatformTextureSettings(android);
                importer.SaveAndReimport();
                count++;
                Debug.Log("[BroforceAndroid] Blank texture kept uncompressed: " + path);
            }
            Debug.Log("[BroforceAndroid] Blank textures fixed: " + count);
        }

        static void AssignSceneBundles()
        {
            int count = 0;
            foreach (string folder in SceneBundleFolders)
            {
                string dir = "Assets/BundleAssets/" + folder;
                if (!AssetDatabase.IsValidFolder(dir)) Fail("Missing folder " + dir);
                string bundle = folder.ToLowerInvariant();
                foreach (string guid in AssetDatabase.FindAssets("t:Scene", new[] { dir }))
                {
                    string path = AssetDatabase.GUIDToAssetPath(guid);
                    AssetImporter importer = AssetImporter.GetAtPath(path);
                    if (importer.assetBundleName != bundle)
                    {
                        importer.assetBundleName = bundle;
                        count++;
                    }
                }
            }
            AssetDatabase.RemoveUnusedAssetBundleNames();
            Debug.Log("[BroforceAndroid] Scene bundles assigned (" + count + " changed).");
        }

        // ------------------------------------------------------------------ APK

        [MenuItem("BroforceAndroid/Build APK")]
        public static void BuildApk()
        {
            if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.Android)
                Fail("Active build target is not Android. Run ConfigureAndroid first.");

            ApplyBranding();
            BuildBundles();

            string apk = Arg("-apkPath", Path.Combine(RepoDir, "build/Broforce.apk"));
            Directory.CreateDirectory(Path.GetDirectoryName(apk));

            string[] scenes = EditorBuildSettings.scenes.Where(s => s.enabled).Select(s => s.path).ToArray();
            Debug.Log("[BroforceAndroid] Building APK with scenes: " + string.Join(", ", scenes));

            var report = BuildPipeline.BuildPlayer(scenes, apk, BuildTarget.Android, BuildOptions.None);
            if (!string.IsNullOrEmpty(report)) Fail("BuildPlayer failed: " + report);
            Debug.Log(string.Format("[BroforceAndroid] APK: {0} ({1:N0} MB)", apk, new FileInfo(apk).Length / 1048576.0));
        }

        // Version from <repo>/VERSION; icon and splash background from the art that
        // build-apk.ps1 copies into Assets/BroforceAndroid (personal builds only).
        static void ApplyBranding()
        {
            string versionFile = Path.Combine(RepoDir, "VERSION");
            if (File.Exists(versionFile))
            {
                string version = File.ReadAllText(versionFile).Trim();
                PlayerSettings.bundleVersion = version;
                // 0.1.0 -> 100, 1.2.3 -> 10203
                int[] parts = version.Split('.').Select(p => { int n; return int.TryParse(p, out n) ? n : 0; }).ToArray();
                // System.Math: the game's assembly has its own global "Math" class.
                PlayerSettings.Android.bundleVersionCode = System.Math.Max(1,
                    (parts.Length > 0 ? parts[0] : 0) * 10000 + (parts.Length > 1 ? parts[1] : 0) * 100 + (parts.Length > 2 ? parts[2] : 0));
            }

            const string iconPath = "Assets/BroforceAndroid/Icon.png";
            if (File.Exists(Path.Combine(ProjectDir, iconPath)))
            {
                AssetDatabase.ImportAsset(iconPath);
                Texture2D icon = AssetDatabase.LoadAssetAtPath<Texture2D>(iconPath);
                int count = PlayerSettings.GetIconSizesForTargetGroup(BuildTargetGroup.Android).Length;
                PlayerSettings.SetIconsForTargetGroup(BuildTargetGroup.Android, Enumerable.Repeat(icon, count).ToArray());
                Debug.Log("[BroforceAndroid] App icon set from " + iconPath);
            }

            const string splashPath = "Assets/BroforceAndroid/Splash.png";
            if (File.Exists(Path.Combine(ProjectDir, splashPath)))
            {
                AssetDatabase.ImportAsset(splashPath);
                var importer = (TextureImporter)AssetImporter.GetAtPath(splashPath);
                if (importer.textureType != TextureImporterType.Sprite)
                {
                    importer.textureType = TextureImporterType.Sprite;
                    importer.SaveAndReimport();
                }
                PlayerSettings.SplashScreen.background = AssetDatabase.LoadAssetAtPath<Sprite>(splashPath);
                PlayerSettings.SplashScreen.backgroundColor = new Color32(0x16, 0x0B, 0x08, 0xFF);
                Debug.Log("[BroforceAndroid] Splash background set from " + splashPath);
            }
            AssetDatabase.SaveAssets();
        }

        // ------------------------------------------------------------------ diagnostics

        // Lists, per plugin DLL, how many MonoScripts Unity created (one per
        // MonoBehaviour/ScriptableObject class it could load), and which classes that
        // derive from them it could NOT turn into a MonoScript. Those show up as
        // "missing script" in scenes and break deserialization in the player.
        [MenuItem("BroforceAndroid/Report Scripts")]
        public static void ReportScripts()
        {
            foreach (string dll in Directory.GetFiles(Path.Combine(Application.dataPath, "Plugins"), "*.dll"))
            {
                string assetPath = "Assets/Plugins/" + Path.GetFileName(dll);
                MonoScript[] scripts = AssetDatabase.LoadAllAssetsAtPath(assetPath).OfType<MonoScript>().ToArray();
                var withClass = new HashSet<string>(scripts.Where(s => s.GetClass() != null).Select(s => s.GetClass().FullName));

                int expected = 0;
                var missing = new List<string>();
                System.Reflection.Assembly asm = AppDomain.CurrentDomain.GetAssemblies()
                    .FirstOrDefault(a => a.GetName().Name == Path.GetFileNameWithoutExtension(dll));
                if (asm != null)
                {
                    Type[] types;
                    try { types = asm.GetTypes(); }
                    catch (System.Reflection.ReflectionTypeLoadException e)
                    {
                        types = e.Types.Where(t => t != null).ToArray();
                        foreach (Exception le in e.LoaderExceptions.Take(5))
                            Debug.Log("[BroforceAndroid][scripts]   loader: " + le.Message);
                    }
                    foreach (Type t in types)
                    {
                        if (t.IsAbstract || t.IsGenericTypeDefinition) continue;
                        if (!typeof(MonoBehaviour).IsAssignableFrom(t) && !typeof(ScriptableObject).IsAssignableFrom(t)) continue;
                        expected++;
                        if (!withClass.Contains(t.FullName)) missing.Add(t.FullName);
                    }
                }
                Debug.Log(string.Format("[BroforceAndroid][scripts] {0}: {1} MonoScripts, {2} script classes, {3} without MonoScript{4}",
                    Path.GetFileName(dll), scripts.Length, expected, missing.Count, asm == null ? " (assembly not loaded!)" : ""));
                foreach (string m in missing.Take(40))
                    Debug.Log("[BroforceAndroid][scripts]   no MonoScript: " + m);
            }
        }

        // Imported format of textures on the active platform: -texture "Assets/..." (repeatable).
        public static void ReportTextures()
        {
            string[] args = Environment.GetCommandLineArgs();
            for (int i = 0; i < args.Length - 1; i++)
            {
                if (args[i] != "-texture") continue;
                string path = args[i + 1];
                var importer = AssetImporter.GetAtPath(path) as TextureImporter;
                var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
                if (importer == null || tex == null) { Debug.Log("[BroforceAndroid][tex] not found: " + path); continue; }
                TextureImporterPlatformSettings android = importer.GetPlatformTextureSettings("Android");
                Debug.Log(string.Format("[BroforceAndroid][tex] {0}: {1}x{2} format={3} alphaSource={4} alphaIsTransparency={5} type={6} npot={7} androidOverride={8}/{9} doesSourceHaveAlpha={10}",
                    path, tex.width, tex.height, tex.format, importer.alphaSource, importer.alphaIsTransparency,
                    importer.textureType, importer.npotScale, android.overridden, android.format, importer.DoesSourceTextureHaveAlpha()));
            }
        }

        // ------------------------------------------------------------------ helpers

        static string Arg(string name, string fallback)
        {
            string[] args = Environment.GetCommandLineArgs();
            int i = Array.IndexOf(args, name);
            return i >= 0 && i + 1 < args.Length ? args[i + 1] : fallback;
        }

        static string FindJdk8()
        {
            if (!Directory.Exists(@"C:\Java")) return null;
            return Directory.GetDirectories(@"C:\Java", "jdk8*").FirstOrDefault();
        }

        static void Fail(string message)
        {
            Debug.LogError("[BroforceAndroid] " + message);
            if (UnityEditorInternal.InternalEditorUtility.inBatchMode) EditorApplication.Exit(1);
            throw new Exception(message);
        }
    }
}
