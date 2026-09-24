using Mono.Cecil;
using BroforceAndroid.Patcher;

// Usage: BroforceAndroid.Patcher <ExportedProject> <BroforceAndroid.Runtime.dll> <GameManagedDir>
//
// Patches the game DLLs in <ExportedProject>/Assets/Plugins in place. The first run
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

var assemblies = Patches.All.Select(p => p.Assembly).Distinct().ToList();

// 1. Back up the originals once, then always restore from the backup.
Directory.CreateDirectory(backup);
foreach (var name in assemblies)
{
    var dll = Path.Combine(plugins, name + ".dll");
    var saved = Path.Combine(backup, name + ".dll");
    if (!File.Exists(saved))
    {
        if (!File.Exists(dll)) return Fail($"{dll} not found");
        File.Copy(dll, saved);
    }
    File.Copy(saved, dll, overwrite: true);
}

// 2. Ship our runtime next to the game DLLs.
File.Copy(runtimeDll, Path.Combine(plugins, Path.GetFileName(runtimeDll)), overwrite: true);

// 3. Patch.
var resolver = new DefaultAssemblyResolver();
resolver.AddSearchDirectory(plugins);
resolver.AddSearchDirectory(managed);
var readerParams = new ReaderParameters { AssemblyResolver = resolver, ReadWrite = false, InMemory = true };

using var runtime = AssemblyDefinition.ReadAssembly(runtimeDll, readerParams);
var hooks = runtime.MainModule.GetType("BroforceAndroid.Hooks")
    ?? throw new InvalidOperationException("BroforceAndroid.Hooks not found in runtime DLL");

// Apply everything in memory first; only write if every patch succeeded.
var failed = 0;
var patched = new List<(AssemblyDefinition Asm, string Path)>();
foreach (var group in Patches.All.GroupBy(p => p.Assembly))
{
    var path = Path.Combine(plugins, group.Key + ".dll");
    var asm = AssemblyDefinition.ReadAssembly(path, readerParams);
    var module = asm.MainModule;
    patched.Add((asm, path));

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

try
{
    foreach (var (asm, path) in patched)
    {
        asm.Write(path);
        asm.Dispose();
    }
}
catch (Exception e)
{
    // Leave the project in its original state rather than half-patched.
    foreach (var name in assemblies)
        File.Copy(Path.Combine(backup, name + ".dll"), Path.Combine(plugins, name + ".dll"), overwrite: true);
    return Fail($"writing failed, original DLLs restored: {e.Message}");
}

Console.WriteLine($"Patched {Patches.All.Length} methods in {assemblies.Count} assemblies.");
return 0;

static int Fail(string message)
{
    Console.Error.WriteLine("error: " + message);
    return 1;
}
