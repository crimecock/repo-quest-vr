using Mono.Cecil;
using Mono.Cecil.Cil;

// IlCheck: checks baked assemblies before the long Unity/IL2CPP build.
//   IlCheck stack <dll>...            methods whose IL stack depth is inconsistent (what IL2CPP rejects as invalid IL)
//   IlCheck diff <original> <baked>   per changed method: instruction counts and how much stayed equal at the start/end.
//                                     A transpiler target that did not change is a patch that silently matched nothing;
//                                     a change in the last few instructions after an Advance(-N) is suspicious.
//   IlCheck refs <dll>... [--search <dir>]...   type and member references that do not resolve against the folders
//   IlCheck types <dll>... [--search <dir>]...  class-typed values stored into locals/fields and `this` of calls,
//                                     against their declared types (IL2CPP's C++ is typed, clang rejects mismatches)
if (args.Length >= 2 && args[0] == "stack")
{
    int bad = 0, total = 0;
    foreach (var path in args.Skip(1))
    {
        var module = ModuleDefinition.ReadModule(path);
        foreach (var m in module.GetTypes().SelectMany(t => t.Methods).Where(m => m.HasBody))
        {
            total++;
            var err = Check(m);
            if (err != null) { bad++; Console.WriteLine($"{Path.GetFileName(path)}: {m.FullName}: {err}"); }
        }
    }
    Console.WriteLine($"{total} methods, {bad} with stack errors");
    return bad == 0 ? 0 : 1;
}
if (args.Length >= 2 && args[0] is "types" or "refs")
{
    var dlls = new List<string>(); var dirs = new List<string>();
    for (var k = 1; k < args.Length; k++)
        if (args[k] == "--search" && k + 1 < args.Length) dirs.Add(args[++k]); else dlls.Add(args[k]);
    return args[0] == "types" ? TypeCheck.Run(dlls, dirs) : RefCheck.Run(dlls, dirs);
}
if (args.Length == 3 && args[0] == "diff")
{
    var a = ModuleDefinition.ReadModule(args[1]);
    var b = ModuleDefinition.ReadModule(args[2]);
    var orig = a.GetTypes().SelectMany(t => t.Methods).Where(m => m.HasBody).ToDictionary(m => m.FullName, m => m);
    foreach (var m in b.GetTypes().SelectMany(t => t.Methods).Where(m => m.HasBody))
    {
        if (!orig.TryGetValue(m.FullName, out var o)) continue;
        var x = o.Body.Instructions.Select(Text).ToList();
        var y = m.Body.Instructions.Select(Text).ToList();
        if (x.SequenceEqual(y)) continue;
        int p = 0; while (p < x.Count && p < y.Count && x[p] == y[p]) p++;
        int s = 0; while (s < x.Count - p && s < y.Count - p && x[x.Count - 1 - s] == y[y.Count - 1 - s]) s++;
        Console.WriteLine($"{m.DeclaringType.FullName}::{m.Name}  orig {x.Count} new {y.Count}  same-prefix {p} same-suffix {s}");
    }
    return 0;
}
Console.Error.WriteLine("usage: IlCheck stack <dll>... | diff <original.dll> <baked.dll> | types|refs <dll>... [--search <dir>]...");
return 2;

static string Text(Instruction i) => i.OpCode.Name + " " + (i.Operand switch
{
    MemberReference r => r.Name, Instruction => "->", Instruction[] => "switch", null => "", var o => o.ToString()
});

static string? Check(MethodDefinition m)
{
    var ins = m.Body.Instructions;
    var depth = new Dictionary<Instruction, int>();
    var work = new Stack<(Instruction, int)>();
    work.Push((ins[0], 0));
    foreach (var h in m.Body.ExceptionHandlers)
    {
        work.Push((h.HandlerStart, h.HandlerType is ExceptionHandlerType.Catch or ExceptionHandlerType.Filter ? 1 : 0));
        if (h.FilterStart != null) work.Push((h.FilterStart, 1));
        work.Push((h.TryStart, 0));
    }
    while (work.Count > 0)
    {
        var (i, d) = work.Pop();
        while (i != null)
        {
            if (depth.TryGetValue(i, out var seen))
            {
                if (seen != d) return $"depth {seen} vs {d} at IL_{i.Offset:x4} {i.OpCode}";
                break;
            }
            depth[i] = d;
            d -= Pops(i, m); if (d < 0) return $"underflow at IL_{i.Offset:x4} {i.OpCode}";
            d += Pushes(i);
            var fc = i.OpCode.FlowControl;
            if (i.OpCode.Code == Code.Ret)
            {
                const int want = 0; // ret has popped the return value already
                if (d != want) return $"{d} left on stack at ret IL_{i.Offset:x4}";
                break;
            }
            if (i.OpCode.Code is Code.Leave or Code.Leave_S) { work.Push(((Instruction)i.Operand, 0)); break; }
            if (fc == FlowControl.Throw || i.OpCode.Code is Code.Endfinally or Code.Endfilter) break;
            if (fc == FlowControl.Branch) { work.Push(((Instruction)i.Operand, d)); break; }
            if (fc == FlowControl.Cond_Branch)
            {
                if (i.Operand is Instruction[] targets) foreach (var t in targets) work.Push((t, d));
                else work.Push(((Instruction)i.Operand, d));
            }
            i = i.Next;
        }
    }
    return null;
}

static int Pops(Instruction i, MethodDefinition m)
{
    switch (i.OpCode.StackBehaviourPop)
    {
        case StackBehaviour.Pop0: return 0;
        case StackBehaviour.Pop1: case StackBehaviour.Popi: case StackBehaviour.Popref: return 1;
        case StackBehaviour.Pop1_pop1: case StackBehaviour.Popi_pop1: case StackBehaviour.Popi_popi: case StackBehaviour.Popi_popi8:
        case StackBehaviour.Popi_popr4: case StackBehaviour.Popi_popr8: case StackBehaviour.Popref_pop1: case StackBehaviour.Popref_popi: return 2;
        case StackBehaviour.Popi_popi_popi: case StackBehaviour.Popref_popi_popi: case StackBehaviour.Popref_popi_popi8:
        case StackBehaviour.Popref_popi_popr4: case StackBehaviour.Popref_popi_popr8: case StackBehaviour.Popref_popi_popref: return 3;
        case StackBehaviour.PopAll: return 0;
        case StackBehaviour.Varpop:
            if (i.OpCode.Code == Code.Ret) return m.ReturnType.MetadataType == MetadataType.Void ? 0 : 1;
            if (i.Operand is MethodReference mr)
            {
                var n = mr.Parameters.Count + (mr.HasThis && i.OpCode.Code != Code.Newobj ? 1 : 0);
                if (i.OpCode.Code == Code.Calli) n++;
                return n;
            }
            if (i.Operand is CallSite cs) return cs.Parameters.Count + (cs.HasThis ? 1 : 0) + 1;
            return 0;
    }
    return 0;
}

static int Pushes(Instruction i)
{
    switch (i.OpCode.StackBehaviourPush)
    {
        case StackBehaviour.Push0: return 0;
        case StackBehaviour.Push1_push1: return 2;
        case StackBehaviour.Varpush:
            if (i.Operand is MethodReference mr)
                return i.OpCode.Code == Code.Newobj ? 1 : (mr.ReturnType.MetadataType == MetadataType.Void ? 0 : 1);
            if (i.Operand is CallSite cs) return cs.ReturnType.MetadataType == MetadataType.Void ? 0 : 1;
            return 0;
        default: return 1;
    }
}
