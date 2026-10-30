using System.Text;
using System.Text.Json;
using RepoQuest.Builder.Game;
using RepoQuest.Builder.Pipeline;
using RepoQuest.Builder.Setup;

namespace RepoQuest.Builder.Cli;

/// <summary>
/// `check`: what a game update broke, in minutes and without Unity, before the hour-long build.
///   1. the game's code against the kit's tested versions (--quick stops here: exit 0 tested, 3 not)
///   2. the bake: RepoXR's patches and the Standalone overrides into the game's code (failed patch classes)
///   3. IlCheck on the baked assemblies: invalid IL (IL2CPP refuses it), class-type mismatches (clang refuses them),
///      patched methods that did not change (a patch that silently matched nothing) or changed only at their very end
///      (a transpiler that lost its anchor and cut into the method's tail)
///   4. IlCheck refs: the game, RepoXR, RepoXR.Standalone and SteamShim calling something the others do not have
///   5. scripts/check_game.py: Unity version, Addressables and the player catalog, package DLLs, the set of DLLs
/// Report: &lt;workspace&gt;/check-report.md. Exit 0 when nothing failed, 1 otherwise.
/// </summary>
internal static class CheckCommand
{
    private sealed record Finding(string Level, string Area, string Message);

    public static async Task<int> RunAsync(Options options)
    {
        var (workspace, kit, gamePath, unityRoot) = Commands.Resolve(options);
        workspace.Create();
        Log.OpenFile(Path.Combine(workspace.Logs, "check.log"));
        var state = BuildState.Load(workspace.StatePath);
        gamePath ??= state.GamePath ?? GameLocator.Find()
            ?? throw new BuildException("R.E.P.O. not found; pass --game <folder with REPO_Data>");
        if (!GameInstall.IsValid(gamePath))
            throw new BuildException($"{gamePath} is not a R.E.P.O. installation (no REPO_Data/Managed/Assembly-CSharp.dll)");
        var game = new GameInstall(gamePath);

        var hash = game.AssemblyHash();
        var tested = kit.Manifest.TestedGames.FirstOrDefault(g => g.AssemblyCSharp == hash);
        Console.WriteLine(tested is not null
            ? $"game: {tested.Name}, tested with kit {kit.Version}"
            : $"game: {game.Version() ?? "unknown version"} (Assembly-CSharp {hash[..12]}), NOT tested with kit {kit.Version}");
        if (options.Has("quick"))
            return tested is not null ? 0 : 3;

        var findings = new List<Finding>
        {
            tested is not null
                ? new("ok", "game", $"{tested.Name}, in the kit's tested versions")
                : new("warn", "game", $"Assembly-CSharp {hash} is not in the kit's tested versions"),
        };

        // 2. The bake, as the build runs it (it also leaves the build's bake step done)
        var unity = unityRoot is not null ? new UnityInstall(unityRoot) : UnityInstall.Find(kit.Manifest.Unity.Version);
        var buildOptions = new BuildOptions
        {
            Only = new HashSet<string> { "bake" },
            Force = true,
            VersionName = kit.Version == "dev" ? "0.0.0" : kit.Version,
        };
        using var cancel = new CancellationTokenSource();
        Console.CancelKeyPress += (_, e) =>
        {
            e.Cancel = true;
            cancel.Cancel();
        };
        var context = await BuildSession.PrepareAsync(workspace, kit, game, unity, buildOptions, state,
            new ConsoleProgress(), cancel.Token);
        try
        {
            await BuildPipeline.RunAsync(context, cancel.Token);
        }
        catch (BuildException e)
        {
            findings.Add(new("fail", "bake", e.Message));
        }

        var baked = workspace.Baked;
        var report = Path.Combine(baked, "bake-report.json");
        var patchedMethods = new List<string>();
        if (File.Exists(report))
            ReadBakeReport(report, findings, patchedMethods, Path.Combine(kit.Scripts, "patch_packages.py"));
        else
            findings.Add(new("fail", "bake", "no bake report: the baker did not run"));

        // 3-4. IlCheck
        var deps = new[]
        {
            await context.ThirdParty.RepoXRRuntimeDepsAsync(cancel.Token),
            await context.ThirdParty.BepInExCoreAsync(cancel.Token),
            await context.ThirdParty.NuGetLibAsync("bepinex.baselib", cancel.Token),
            await context.ThirdParty.NuGetLibAsync("customdiscoverstatelib", cancel.Token),
        };
        if (File.Exists(Path.Combine(baked, "Assembly-CSharp.dll")))
        {
            var bakedDlls = Directory.EnumerateFiles(baked, "*.dll").Order(StringComparer.Ordinal).ToList();
            var search = new[] { baked, kit.SteamDir, Path.GetDirectoryName(kit.StandaloneDll)! }
                .Concat(deps).Append(game.Managed).SelectMany(d => new[] { "--search", d }).ToList();

            var (stackOk, stackLines) = await IlCheckAsync(context, ["stack", .. bakedDlls], cancel.Token);
            AddLines(findings, "il", stackOk, stackLines, "no invalid IL in the baked assemblies");

            var (typesOk, typesLines) = await IlCheckAsync(context, ["types", .. bakedDlls, .. search], cancel.Token);
            AddLines(findings, "types", typesOk, typesLines, "no class-type mismatches");

            var refTargets = new List<string>(bakedDlls.Where(d => Path.GetFileName(d) is "Assembly-CSharp.dll" or "RepoXR.dll"))
                { kit.StandaloneDll, Path.Combine(kit.SteamDir, "Facepunch.Steamworks.Win64.dll") };
            var (refsOk, refsLines) = await IlCheckAsync(context, ["refs", .. refTargets, .. search], cancel.Token);
            AddLines(findings, "refs", refsOk, refsLines, "every reference between the game, RepoXR, Standalone and SteamShim resolves");

            var (_, diffLines) = await IlCheckAsync(context,
                ["diff", Path.Combine(game.Managed, "Assembly-CSharp.dll"), Path.Combine(baked, "Assembly-CSharp.dll")], cancel.Token);
            CheckPatchedMethods(findings, patchedMethods, diffLines);
        }

        // 5. The game's data against the last tested version
        var gameReport = Path.Combine(workspace.Root, "check-game.json");
        FileOps.DeleteFile(gameReport);
        try
        {
            await context.RunScriptAsync("check_game.py", cancel.Token, game.Data, "--out", gameReport);
            using var json = JsonDocument.Parse(File.ReadAllText(gameReport));
            foreach (var c in json.RootElement.GetProperty("checks").EnumerateArray())
                findings.Add(new(c.GetProperty("level").GetString()!, c.GetProperty("area").GetString()!,
                    c.GetProperty("message").GetString()!));
        }
        catch (BuildException e)
        {
            findings.Add(new("fail", "game data", $"check_game.py: {e.Message}"));
        }

        var markdown = Report(game, kit, findings);
        var reportPath = Path.Combine(workspace.Root, "check-report.md");
        File.WriteAllText(reportPath, markdown);
        Console.WriteLine();
        foreach (var f in findings)
            Console.WriteLine($"{f.Level.ToUpperInvariant(),-4} {f.Area}: {f.Message}");
        var failed = findings.Count(f => f.Level == "fail");
        var warned = findings.Count(f => f.Level == "warn");
        Console.WriteLine();
        Console.WriteLine(failed == 0
            ? $"check: no failures ({warned} warnings). Report: {reportPath}"
            : $"check: {failed} failures, {warned} warnings. Report: {reportPath}");
        return failed == 0 ? 0 : 1;
    }

    private static void ReadBakeReport(string path, List<Finding> findings, List<string> patchedMethods, string packagePatches)
    {
        using var json = JsonDocument.Parse(File.ReadAllText(path));
        var root = json.RootElement;
        int Count(string name) => root.TryGetProperty(name, out var e)
            ? e.ValueKind == JsonValueKind.Array ? e.GetArrayLength() : e.ValueKind == JsonValueKind.Number ? e.GetInt32() : 0
            : 0;
        var failed = root.TryGetProperty("failed", out var f) && f.ValueKind == JsonValueKind.Array ? f : default;
        if (failed.ValueKind == JsonValueKind.Array)
            foreach (var item in failed.EnumerateArray())
                findings.Add(new("fail", "bake", $"{Text(item, "Name")}: {Text(item, "error")}"));
        if (root.TryGetProperty("hookErrors", out var hooks) && hooks.ValueKind == JsonValueKind.Array)
            foreach (var item in hooks.EnumerateArray())
                findings.Add(new("fail", "bake", $"hook: {item}"));
        // A transpiler search that found nothing: without ThrowIfInvalid, the edits that follow land at the end of the
        // method (RepoXR's ForceHoldPatch on 0.5.0 kept grabbing disabled that way). Searches failing after earlier
        // matches of the same transpiler are loops running out of matches and are left out
        if (root.TryGetProperty("lostAnchors", out var anchors) && anchors.ValueKind == JsonValueKind.Array)
            foreach (var miss in anchors.EnumerateArray()
                         .Where(m => !(m.TryGetProperty("AfterSuccess", out var after) && after.GetBoolean()))
                         .Select(m => $"transpiler {Text(m, "Transpiler")} found nothing in {Text(m, "Target")}: {Text(m, "Search")}")
                         .Distinct())
                findings.Add(new("warn", "anchors", $"{miss} (check that the patch still does what it should)"));
        if (root.TryGetProperty("assemblies", out var assemblies) && assemblies.ValueKind == JsonValueKind.Array)
            foreach (var a in assemblies.EnumerateArray())
                if (a.TryGetProperty("Errors", out var errors) && errors.ValueKind == JsonValueKind.Array)
                    foreach (var error in errors.EnumerateArray())
                        findings.Add(new("fail", "bake", $"{Text(a, "Name")}: {error}"));
        // IL baked into an assembly the Unity build replaces is lost without a word: engine modules come from the
        // editor (Unity 6 made many engine externs managed wrappers, e.g. Camera.set_targetTexture), packages are
        // compiled from source, where only scripts/patch_packages.py can carry a patch
        var packageText = File.Exists(packagePatches) ? File.ReadAllText(packagePatches) : "";
        if (root.TryGetProperty("methods", out var methods) && methods.ValueKind == JsonValueKind.Array)
            foreach (var m in methods.EnumerateArray())
            {
                var assembly = Text(m, "assembly");
                var method = Text(m, "method");
                if (assembly == "Assembly-CSharp")
                    patchedMethods.Add(method);
                if (Text(m, "native") == "True")
                    continue;
                if (assembly == "UnityEngine" || (assembly.StartsWith("UnityEngine.", StringComparison.Ordinal) && assembly.EndsWith("Module", StringComparison.Ordinal)))
                    findings.Add(new("fail", "bake", $"{method} was baked into {assembly}, which the Unity build replaces: the patch would be lost (hook it at call sites)"));
                else if (assembly.StartsWith("Unity.", StringComparison.Ordinal) || assembly == "UnityEngine.UI")
                {
                    var type = method.Split("::")[0].Split('.')[^1];
                    var member = method.Split("::")[^1].Replace("get_", "").Replace("set_", "");
                    if (!packageText.Contains($"{type}.{member}", StringComparison.Ordinal))
                        findings.Add(new("warn", "bake", $"{method} was baked into the package {assembly}, which is compiled from source: scripts/patch_packages.py has to carry it"));
                }
            }
        findings.Add(new(Count("failed") == 0 ? "ok" : "fail", "bake",
            $"patch classes: {Count("applied")} applied, {Count("skipped")} skipped, {Count("failed")} failed"));
    }

    private static string Text(JsonElement e, string name) =>
        e.TryGetProperty(name, out var v) ? v.ValueKind == JsonValueKind.String ? v.GetString() ?? "" : v.ToString() : "";

    /// <summary>
    /// Patched game methods: unchanged = a patch that matched nothing; changed only in the last instructions with no
    /// more instructions than before = a transpiler that lost its anchor (CodeMatcher at the end, then Advance(-N))
    /// </summary>
    private static void CheckPatchedMethods(List<Finding> findings, List<string> patched, IReadOnlyList<string> diffLines)
    {
        var changed = new Dictionary<string, (int Orig, int New, int Prefix)>();
        foreach (var line in diffLines)
        {
            var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 9 || parts[1] != "orig") continue;
            var name = parts[0].Replace('/', '+');
            changed[name] = (int.Parse(parts[2]), int.Parse(parts[4]), int.Parse(parts[6]));
        }
        var unchanged = patched.Where(m => !changed.ContainsKey(m)).ToList();
        foreach (var m in unchanged)
            findings.Add(new("warn", "patches", $"{m} is patched but unchanged: a patch that matched nothing (fine only for patches meant to be skipped)"));
        foreach (var (name, (orig, now, prefix)) in changed)
            if (prefix >= orig - 8 && now < orig)
                findings.Add(new("fail", "patches", $"{name}: changed only in its last instructions ({orig} -> {now}): a transpiler that lost its anchor"));
        if (unchanged.Count == 0)
            findings.Add(new("ok", "patches", $"all {patched.Count} patched game methods changed"));
    }

    private static async Task<(bool Ok, IReadOnlyList<string> Lines)> IlCheckAsync(BuildContext context,
        IReadOnlyList<string> args, CancellationToken ct)
    {
        var lines = new List<string>();
        var result = await ProcessRunner.RunAsync(new ProcessSpec
        {
            FileName = context.Tools.Command[0],
            Arguments = [.. context.Tools.Command.Skip(1), "il-check", .. args],
            LogPrefix = "[il-check] ",
        }, line => lines.Add(line), ct);
        return (result.ExitCode == 0, lines);
    }

    private static void AddLines(List<Finding> findings, string area, bool ok, IReadOnlyList<string> lines, string okText)
    {
        if (ok)
        {
            findings.Add(new("ok", area, okText));
            return;
        }
        var problems = lines.Where(l => l.Contains(": ") && !l.StartsWith("   at ", StringComparison.Ordinal)).ToList();
        foreach (var line in problems.Take(40))
            findings.Add(new("fail", area, line));
        if (problems.Count > 40)
            findings.Add(new("fail", area, $"... and {problems.Count - 40} more (see logs/check.log)"));
        if (problems.Count == 0)
            findings.Add(new("fail", area, lines.LastOrDefault() ?? "il-check failed"));
    }

    private static string Report(GameInstall game, Kit kit, List<Finding> findings)
    {
        var text = new StringBuilder();
        text.AppendLine("# Game update check").AppendLine();
        text.AppendLine($"- Game: `{game.Path}`, {game.Version() ?? "version unknown"}, Assembly-CSharp `{game.AssemblyHash()}`");
        text.AppendLine($"- Kit: {kit.Version} (Unity {kit.Manifest.Unity.Version})");
        text.AppendLine($"- Date: {DateTime.Now:yyyy-MM-dd HH:mm}").AppendLine();
        foreach (var level in new[] { "fail", "warn", "ok" })
        {
            var items = findings.Where(f => f.Level == level).ToList();
            if (items.Count == 0) continue;
            text.AppendLine(level switch { "fail" => "## Failures", "warn" => "## Warnings", _ => "## OK" }).AppendLine();
            foreach (var f in items)
                text.AppendLine($"- **{f.Area}**: {f.Message.Replace("\n", " ")}");
            text.AppendLine();
        }
        return text.ToString();
    }
}
