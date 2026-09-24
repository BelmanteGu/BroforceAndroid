using Mono.Cecil;
using Mono.Cecil.Cil;

namespace BroforceAndroid.Patcher;

/// <summary>
/// Every change we make to the game's code. Each patch names its target exactly
/// and throws if it can't find it, so a game update can't be silently mis-patched.
/// See docs/adr/0001-patching-strategy.md.
/// </summary>
static class Patches
{
    public static readonly Patch[] All =
    {
        // --- Steam (#6) ---------------------------------------------------------
        // Steamworks.NET P/Invokes into CSteamworks, which doesn't exist on Android:
        // every call throws DllNotFoundException instead of reporting "no Steam".
        new("steam-init", "Assembly-CSharp-firstpass", "Steamworks.SteamAPI", "Init",
            "SteamAPI.Init() returns false",
            ctx => ReturnConstant(ctx.Method, false)),

        new("steam-running", "Assembly-CSharp-firstpass", "Steamworks.SteamAPI", "IsSteamRunning",
            "SteamAPI.IsSteamRunning() returns false",
            ctx => ReturnConstant(ctx.Method, false)),

        new("steam-enabled", "Assembly-CSharp", "SteamController", "IsSteamEnabled",
            "SteamController.IsSteamEnabled() returns false (28 call sites, including saves and language)",
            ctx => ReturnConstant(ctx.Method, false)),

        // --- Saves (#9) ---------------------------------------------------------
        new("save-path", "Assembly-CSharp", "FileIO", "GetPlatformDataPath",
            "FileIO.GetPlatformDataPath(path) resolves under Application.persistentDataPath",
            ctx =>
            {
                var hook = ctx.Hook("GetPlatformDataPath");
                ReplaceBody(ctx.Method, il =>
                {
                    il.Emit(OpCodes.Ldarg_0);
                    il.Emit(OpCodes.Call, hook);
                    il.Emit(OpCodes.Ret);
                });
            }),

        // --- Input (#16) --------------------------------------------------------
        new("rewired-platform", "Assembly-CSharp", "Rewired.InputManager", "DetectPlatform",
            "Rewired.InputManager.DetectPlatform() asks the runtime instead of hardcoding Windows",
            ctx =>
            {
                // Original ends with: this.platform = Platform.Windows (ldarg.0; ldc.i4.1; stfld platform)
                var il = ctx.Method.Body.GetILProcessor();
                var store = ctx.Method.Body.Instructions.LastOrDefault(i =>
                    i.OpCode == OpCodes.Stfld && ((FieldReference)i.Operand).Name == "platform");
                if (store?.Previous is not { } load || load.OpCode != OpCodes.Ldc_I4_1)
                    throw new PatchException("expected 'platform = Platform.Windows' (ldc.i4.1; stfld platform)");
                il.Replace(load, il.Create(OpCodes.Call, ctx.Hook("GetRewiredPlatform")));
            }),

        // --- Windows-only features (#8) -----------------------------------------
        new("alienfx", "Assembly-CSharp", "AlienFXControllerManaged", "Start",
            "AlienFXControllerManaged.Start() marks LightFX as unsupported instead of calling LightFX.dll",
            ctx =>
            {
                var flag = ctx.Method.DeclaringType.Fields.SingleOrDefault(f => f.Name == "LightFXNotSupportedOnThisMachine")
                    ?? throw new PatchException("field LightFXNotSupportedOnThisMachine not found");
                ReplaceBody(ctx.Method, il =>
                {
                    il.Emit(OpCodes.Ldarg_0);
                    il.Emit(OpCodes.Ldc_I4_1);
                    il.Emit(OpCodes.Stfld, flag);
                    il.Emit(OpCodes.Ret);
                });
            }),

        new("quickcapture", "Assembly-CSharp", "QuickCapture", "LateUpdate",
            "QuickCapture.LateUpdate() does nothing (NatCorder dev capture tool, runs every frame)",
            ctx => ReplaceBody(ctx.Method, il => il.Emit(OpCodes.Ret))),
    };

    static void ReturnConstant(MethodDefinition method, bool value)
    {
        if (method.ReturnType.FullName != "System.Boolean")
            throw new PatchException($"expected bool return type, found {method.ReturnType.FullName}");
        ReplaceBody(method, il =>
        {
            il.Emit(value ? OpCodes.Ldc_I4_1 : OpCodes.Ldc_I4_0);
            il.Emit(OpCodes.Ret);
        });
    }

    static void ReplaceBody(MethodDefinition method, Action<ILProcessor> emit)
    {
        var body = method.Body;
        body.Instructions.Clear();
        body.ExceptionHandlers.Clear();
        body.Variables.Clear();
        emit(body.GetILProcessor());
    }
}

record Patch(string Id, string Assembly, string Type, string Method, string Description, Action<PatchContext> Apply);

class PatchContext(MethodDefinition method, ModuleDefinition module, TypeDefinition hooks)
{
    public MethodDefinition Method { get; } = method;

    /// <summary>Imports a public static method of BroforceAndroid.Hooks into the patched module.</summary>
    public MethodReference Hook(string name) =>
        module.ImportReference(hooks.Methods.SingleOrDefault(m => m.Name == name && m.IsStatic)
            ?? throw new PatchException($"runtime hook BroforceAndroid.Hooks.{name} not found"));
}

class PatchException(string message) : Exception(message);
