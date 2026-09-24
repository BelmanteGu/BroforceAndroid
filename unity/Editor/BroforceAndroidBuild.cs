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

            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.Android, false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android,
                new[] { UnityEngine.Rendering.GraphicsDeviceType.OpenGLES3, UnityEngine.Rendering.GraphicsDeviceType.OpenGLES2 });

            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel19;
            // Android 14+ refuses to install apps targeting < 23. 28 is what sdk-legacy ships.
            PlayerSettings.Android.targetSdkVersion = (AndroidSdkVersions)28;

            PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = true;
            PlayerSettings.Android.forceSDCardPermission = false;
            PlayerSettings.Android.forceInternetPermission = false;
            PlayerSettings.Android.androidIsGame = true;
            // Gamepad only: don't require a touchscreen, so the game isn't hidden on TV boxes.
            PlayerSettings.Android.androidTVCompatibility = true;

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
            AssetBundleManifest manifest = BuildPipeline.BuildAssetBundles(outDir,
                BuildAssetBundleOptions.ChunkBasedCompression, target);
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

            BuildBundles();

            string apk = Arg("-apkPath", Path.Combine(RepoDir, "build/Broforce.apk"));
            Directory.CreateDirectory(Path.GetDirectoryName(apk));

            string[] scenes = EditorBuildSettings.scenes.Where(s => s.enabled).Select(s => s.path).ToArray();
            Debug.Log("[BroforceAndroid] Building APK with scenes: " + string.Join(", ", scenes));

            var report = BuildPipeline.BuildPlayer(scenes, apk, BuildTarget.Android, BuildOptions.None);
            if (!string.IsNullOrEmpty(report)) Fail("BuildPlayer failed: " + report);
            Debug.Log(string.Format("[BroforceAndroid] APK: {0} ({1:N0} MB)", apk, new FileInfo(apk).Length / 1048576.0));
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
