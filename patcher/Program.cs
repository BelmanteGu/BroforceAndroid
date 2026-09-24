using Mono.Cecil;
using BroforceAndroid.Patcher;

// Usage: BroforceAndroid.Patcher <ExportedProject> <BroforceAndroid.Runtime.dll> <GameManagedDir>
//
// Patches the game DLLs in <ExportedProject>/Assets/Plugins in place, then renames the
// assemblies whose names Unity reserves for its own script compilation. The first run
// backs the originals up to <ExportedProject>/../original-dlls, and every run starts
// from that backup, so running it again is safe. <GameManagedDir> (the game's
// Broforce_beta_Data/Managed) is only used to resolve UnityEngine references.

if (args.Length != 3)
{
    Console.Error.WriteLine("usage: BroforceAndroid.Patcher <ExportedProject> <BroforceAndroid.Runtime.dll> <GameManagedDir>");
    return 2;
}

var project = Path.GetFullPath(args[0]);
var runtimeDll = Path.GetFullPath(args[1]);
var managed = Path.GetFullPath(args[2]);
var plugins = Path.Combine(project, "Assets", "Plugins");
var backup = Path.Combine(Path.GetDirectoryName(project)!, "original-dlls");

if (!Directory.Exists(plugins)) return Fail($"{plugins} not found. Export with -ScriptMode DllExportWithoutRenaming.");
if (!File.Exists(runtimeDll)) return Fail($"{runtimeDll} not found. Build runtime/ first.");
if (!File.Exists(Path.Combine(managed, "UnityEngine.CoreModule.dll"))) return Fail($"{managed} is not the game's Managed folder.");

string DllPath(string name) => Path.Combine(plugins, name + ".dll");

// 0. Undo a previous run's renames: bring the .meta files (which hold the GUIDs that
//    scenes reference) back to the original names and drop the renamed DLLs.
foreach (var (from, to) in Renames.All)
{
    var renamedMeta = DllPath(to) + ".meta";
    if (File.Exists(renamedMeta) && !File.Exists(DllPath(from) + ".meta"))
        File.Move(renamedMeta, DllPath(from) + ".meta");
    if (File.Exists(DllPath(to))) File.Delete(DllPath(to));
}

// Everything we rewrite: patch targets, renamed assemblies, and the one that grants
// InternalsVisibleTo to a renamed assembly.
var assemblies = Patches.All.Select(p => p.Assembly)
    .Concat(Renames.All.Select(r => r.From))
    .Concat(new[] { Renames.InternalsVisibleToHolder })
    .Distinct()
    .Where(name => File.Exists(DllPath(name)) || File.Exists(Path.Combine(backup, name + ".dll")))
    .ToList();

// 1. Back up the originals once, then always restore from the backup.
Directory.CreateDirectory(backup);
foreach (var name in assemblies)
{
    var saved = Path.Combine(backup, name + ".dll");
    if (!File.Exists(saved))
    {
        if (!File.Exists(DllPath(name))) return Fail($"{DllPath(name)} not found");
        File.Copy(DllPath(name), saved);
    }
    File.Copy(saved, DllPath(name), overwrite: true);
}

// 2. Ship our runtime next to the game DLLs.
File.Copy(runtimeDll, Path.Combine(plugins, Path.GetFileName(runtimeDll)), overwrite: true);

// 3. Load and patch, all in memory.
var resolver = new InMemoryResolver();
resolver.AddSearchDirectory(plugins);
resolver.AddSearchDirectory(managed);
var readerParams = new ReaderParameters { AssemblyResolver = resolver, ReadWrite = false, InMemory = true };

using var runtime = AssemblyDefinition.ReadAssembly(runtimeDll, readerParams);
var hooks = runtime.MainModule.GetType("BroforceAndroid.Hooks")
    ?? throw new InvalidOperationException("BroforceAndroid.Hooks not found in runtime DLL");

var loaded = assemblies.ToDictionary(name => name, name => AssemblyDefinition.ReadAssembly(DllPath(name), readerParams));

var failed = 0;
foreach (var group in Patches.All.GroupBy(p => p.Assembly))
{
    var module = loaded[group.Key].MainModule;
    foreach (var patch in group)
    {
        try
        {
            var type = module.GetType(patch.Type) ?? throw new PatchException($"type {patch.Type} not found");
            var methods = type.Methods.Where(m => m.Name == patch.Method && m.HasBody
                && (patch.ParamCount is null || m.Parameters.Count == patch.ParamCount)).ToList();
            if (methods.Count != 1)
                throw new PatchException($"expected 1 method {patch.Type}.{patch.Method}, found {methods.Count}");

            patch.Apply(new PatchContext(methods[0], module, hooks));
            Console.WriteLine($"  [ok]   {patch.Id,-18} {patch.Description}");
        }
        catch (PatchException e)
        {
            failed++;
            Console.WriteLine($"  [FAIL] {patch.Id,-18} {group.Key}: {e.Message}");
        }
    }
}

if (failed > 0)
    return Fail($"{failed} patch(es) failed; nothing was written.");

// 4. Rename the reserved assemblies and everything that points at them.
Renames.Apply(loaded, DllPath);
foreach (var asm in loaded.Values)
    resolver.Add(asm);   // so writing can resolve the new names in memory

// 5. Write. Renamed assemblies go to their new file, taking the original .meta along.
try
{
    foreach (var (name, asm) in loaded)
    {
        var target = DllPath(asm.Name.Name);
        asm.Write(target);
        if (target != DllPath(name))
        {
            if (File.Exists(DllPath(name) + ".meta")) File.Move(DllPath(name) + ".meta", target + ".meta", overwrite: true);
            File.Delete(DllPath(name));
            Console.WriteLine($"  [ok]   rename             {name} -> {asm.Name.Name}");
        }
    }
}
catch (Exception e)
{
    // Leave the project in its original state rather than half-patched.
    foreach (var (from, to) in Renames.All)
    {
        if (File.Exists(DllPath(to) + ".meta") && !File.Exists(DllPath(from) + ".meta"))
            File.Move(DllPath(to) + ".meta", DllPath(from) + ".meta");
        if (File.Exists(DllPath(to))) File.Delete(DllPath(to));
    }
    foreach (var name in assemblies)
        File.Copy(Path.Combine(backup, name + ".dll"), DllPath(name), overwrite: true);
    return Fail($"writing failed, original DLLs restored: {e.Message}");
}
finally
{
    foreach (var asm in loaded.Values) asm.Dispose();
}

Console.WriteLine($"Patched {Patches.All.Length} methods; rewrote {loaded.Count} assemblies.");
return 0;

static int Fail(string message)
{
    Console.Error.WriteLine("error: " + message);
    return 1;
}

/// <summary>Resolves assemblies we hold in memory (e.g. under their new names) first.</summary>
class InMemoryResolver : DefaultAssemblyResolver
{
    public void Add(AssemblyDefinition assembly) => RegisterAssembly(assembly);
}
