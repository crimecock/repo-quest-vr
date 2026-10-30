using Mono.Cecil;

/// <summary>
/// IlCheck refs: member and type references of the given assemblies that do not resolve against the search folders.
/// The game, RepoXR, RepoXR.Standalone and SteamShim bind to each other by name; when a game update renames or removes
/// something (or calls a Steam API SteamShim lacks), the build still succeeds and the call fails at runtime.
/// The .NET class libraries (mscorlib, netstandard, System.*) are not followed: their forwarders loop.
/// </summary>
static class RefCheck
{
    public static int Run(IEnumerable<string> paths, IEnumerable<string> searchDirs)
    {
        // The class libraries always from one folder (the game's Managed, which has both mscorlib and netstandard):
        // RepoXR's RuntimeDeps carry a netstandard facade that forwards to mscorlib, the game's mscorlib forwards to
        // netstandard, and Cecil follows such a pair until the stack overflows
        var bclDir = searchDirs.FirstOrDefault(d => File.Exists(Path.Combine(d, "UnityEngine.CoreModule.dll")) &&
                                                    File.Exists(Path.Combine(d, "netstandard.dll")));
        var resolver = new BclResolver(bclDir);
        foreach (var d in searchDirs) resolver.AddSearchDirectory(d);
        // Assemblies whose file name differs from the assembly name (Kistras-CustomDiscoverStateLib)
        var byName = new Dictionary<string, AssemblyDefinition>();
        foreach (var dir in searchDirs.Where(Directory.Exists))
            foreach (var dll in Directory.EnumerateFiles(dir, "*.dll"))
                try
                {
                    var asm = AssemblyDefinition.ReadAssembly(dll, new ReaderParameters { AssemblyResolver = resolver });
                    byName.TryAdd(asm.Name.Name, asm);
                }
                catch (BadImageFormatException) { }
        resolver.ResolveFailure += (_, name) => byName.GetValueOrDefault(name.Name);

        var bad = 0;
        foreach (var path in paths)
        {
            var module = ModuleDefinition.ReadModule(path, new ReaderParameters { AssemblyResolver = resolver });
            var lines = new SortedSet<string>(StringComparer.Ordinal);
            foreach (var t in module.GetTypeReferences())
            {
                if (Bcl(t.Scope)) continue;
                try { if (t.Resolve() == null) lines.Add($"type {t.FullName} ({t.Scope.Name})"); }
                catch (AssemblyResolutionException e) { lines.Add($"assembly {e.AssemblyReference.Name} (for {t.FullName})"); }
            }
            foreach (var m in module.GetMemberReferences())
            {
                if (m.DeclaringType is ArrayType || Bcl(m.DeclaringType.Scope)) continue;
                try
                {
                    var resolved = m is MethodReference mr ? (object?)mr.Resolve() : m is FieldReference fr ? fr.Resolve() : "";
                    if (resolved == null) lines.Add($"member {m.FullName} ({m.DeclaringType.Scope.Name})");
                }
                catch (AssemblyResolutionException e) { lines.Add($"assembly {e.AssemblyReference.Name} (for {m.FullName})"); }
            }
            foreach (var line in lines)
                Console.WriteLine($"{Path.GetFileName(path)}: {line}");
            bad += lines.Count;
        }
        Console.WriteLine($"{bad} unresolved references");
        return bad == 0 ? 0 : 1;
    }

    static bool Bcl(IMetadataScope scope) => BclName(scope.Name);

    internal static bool BclName(string name)
    {
        if (name.EndsWith(".dll", StringComparison.OrdinalIgnoreCase)) name = name[..^4];
        return name is "mscorlib" or "netstandard" or "System" || name.StartsWith("System.", StringComparison.Ordinal) ||
               name.StartsWith("Microsoft.", StringComparison.Ordinal);
    }

    sealed class BclResolver(string? bclDir) : DefaultAssemblyResolver
    {
        private readonly Dictionary<string, AssemblyDefinition> bcl = new();

        public override AssemblyDefinition Resolve(AssemblyNameReference name)
        {
            if (bclDir != null && BclName(name.Name) && File.Exists(Path.Combine(bclDir, name.Name + ".dll")))
            {
                if (!bcl.TryGetValue(name.Name, out var asm))
                    bcl[name.Name] = asm = AssemblyDefinition.ReadAssembly(Path.Combine(bclDir, name.Name + ".dll"),
                        new ReaderParameters { AssemblyResolver = this });
                return asm;
            }
            return base.Resolve(name);
        }
    }
}
