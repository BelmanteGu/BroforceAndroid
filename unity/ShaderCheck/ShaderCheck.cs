// Standalone check for the rewritten shaders, run by scripts/check-shaders.ps1 in a
// throwaway project (export/shadertest). It reports import-time compile errors, then
// makes one material per shader and builds an Android APK, which compiles every
// variant for GLES and doubles as a toolchain smoke test. C# 4 (Unity 2017.4).
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class ShaderCheck
{
    public static void Run()
    {
        EditorPrefs.SetString("AndroidSdkRoot", @"C:\Android\sdk-legacy");
        string jdk = Directory.Exists(@"C:\Java") ? Directory.GetDirectories(@"C:\Java", "jdk8*").FirstOrDefault() : null;
        if (jdk != null) EditorPrefs.SetString("JdkPath", jdk);

        AssetDatabase.Refresh();
        MethodInfo getErrors = typeof(ShaderUtil).GetMethod("GetShaderErrors", BindingFlags.Static | BindingFlags.NonPublic);

        Directory.CreateDirectory("Assets/Resources");
        int errorCount = 0, shaderCount = 0;
        foreach (string guid in AssetDatabase.FindAssets("t:Shader", new[] { "Assets/Shaders" }))
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(path);
            shaderCount++;
            if (getErrors != null)
            {
                Array errors = (Array)getErrors.Invoke(null, new object[] { shader });
                foreach (object e in errors)
                {
                    Type t = e.GetType();
                    bool warning = Convert.ToInt32(t.GetField("warning").GetValue(e)) != 0;
                    if (warning) continue;
                    errorCount++;
                    Debug.LogError(string.Format("[ShaderCheck] ERROR {0}: {1} (line {2}, platform {3})",
                        shader.name, t.GetField("message").GetValue(e), t.GetField("line").GetValue(e),
                        t.GetField("platform").GetValue(e)));
                }
            }
            Material m = new Material(shader);
            AssetDatabase.CreateAsset(m, "Assets/Resources/M" + shaderCount + ".mat");
        }
        AssetDatabase.SaveAssets();
        Debug.Log("[ShaderCheck] " + shaderCount + " shaders, " + errorCount + " import errors");

        // Empty scene: the default camera/light/skybox makes -nographics builds fail on
        // reflection cubemaps, which has nothing to do with our shaders.
        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        EditorSceneManager.SaveScene(scene, "Assets/Test.unity");

        PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.Android, "io.github.belmantegu.shadertest");
        PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.Mono2x);
        PlayerSettings.Android.targetDevice = AndroidTargetDevice.ARMv7;
        PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.Android, false);
        PlayerSettings.SetGraphicsAPIs(BuildTarget.Android,
            new[] { UnityEngine.Rendering.GraphicsDeviceType.OpenGLES3, UnityEngine.Rendering.GraphicsDeviceType.OpenGLES2 });
        PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel19;
        PlayerSettings.Android.targetSdkVersion = (AndroidSdkVersions)28;
        EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Internal;

        string apk = Path.GetFullPath("Build/shadertest.apk");
        Directory.CreateDirectory(Path.GetDirectoryName(apk));
        string result = BuildPipeline.BuildPlayer(new[] { "Assets/Test.unity" }, apk, BuildTarget.Android, BuildOptions.None);
        if (!string.IsNullOrEmpty(result))
        {
            Debug.LogError("[ShaderCheck] BUILD FAILED: " + result);
            EditorApplication.Exit(1);
        }
        Debug.Log("[ShaderCheck] BUILD OK: " + apk + " (" + new FileInfo(apk).Length / 1024 + " KB)");
        EditorApplication.Exit(errorCount > 0 ? 2 : 0);
    }
}
