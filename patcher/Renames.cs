using Mono.Cecil;

namespace BroforceAndroid.Patcher;

/// <summary>
/// Unity reserves the Assembly-CSharp* / Assembly-UnityScript* names for the assemblies
/// it compiles from loose scripts. A precompiled plugin with one of those names is not
/// used to resolve MonoScripts: every script in it shows up as "missing" in the Editor,
/// the build serializes those components without their data, and the player then fails
/// with "globalgamemanagers.assets is corrupted! [Position out of bounds!]".
///
/// Renaming the assemblies (and the references to them) fixes that. Scenes point at
/// scripts through the DLL's .meta GUID plus a hash of namespace and class name, neither
/// of which depends on the assembly name, so the .meta just moves with the file.
/// </summary>
static class Renames
{
    public static readonly (string From, string To)[] All =
    {
        ("Assembly-CSharp", "Broforce.Game"),
        ("Assembly-CSharp-firstpass", "Broforce.Game.Firstpass"),
        ("Assembly-UnityScript", "Broforce.UnityScript"),
        ("Assembly-UnityScript-firstpass", "Broforce.UnityScript.Firstpass"),
    };

    /// <summary>Grants InternalsVisibleTo("Assembly-CSharp"), which must follow the rename.</summary>
    public const string InternalsVisibleToHolder = "Sisus.Newtonsoft.Json";

    public static void Apply(Dictionary<string, AssemblyDefinition> loaded, Func<string, string> dllPath)
    {
        var map = All.ToDictionary(r => r.From, r => r.To);

        foreach (var (from, to) in All)
        {
            if (!loaded.TryGetValue(from, out var asm)) continue;
            asm.Name.Name = to;
            asm.MainModule.Name = to + ".dll";
        }

        // References from every plugin DLL, not only the ones we rewrite for other reasons.
        foreach (var file in Directory.GetFiles(Path.GetDirectoryName(dllPath("x"))!, "*.dll"))
        {
            var name = Path.GetFileNameWithoutExtension(file);
            if (loaded.ContainsKey(name) || map.ContainsValue(name)) continue;
            using var other = AssemblyDefinition.ReadAssembly(file, new ReaderParameters { InMemory = true });
            if (other.MainModule.AssemblyReferences.Any(r => map.ContainsKey(r.Name)))
                throw new PatchException($"{name} references a renamed assembly; add it to the rewritten set");
        }
        foreach (var asm in loaded.Values)
            foreach (var reference in asm.MainModule.AssemblyReferences)
                if (map.TryGetValue(reference.Name, out var to))
                    reference.Name = to;

        // InternalsVisibleTo("Assembly-CSharp") -> the new name.
        if (loaded.TryGetValue(InternalsVisibleToHolder, out var holder))
        {
            foreach (var attr in holder.CustomAttributes.Where(a => a.AttributeType.Name == "InternalsVisibleToAttribute"))
            {
                var arg = attr.ConstructorArguments[0];
                if (arg.Value is string target && map.TryGetValue(target, out var renamed))
                    attr.ConstructorArguments[0] = new CustomAttributeArgument(arg.Type, renamed);
            }
        }
    }
}
