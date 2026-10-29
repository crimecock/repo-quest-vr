using Mono.Cecil;
using Mono.Cecil.Cil;

/// <summary>
/// IlCheck types: object references stored into locals and fields, and the `this` of instance calls, checked against
/// their declared types. IL2CPP's C++ is typed, so a transpiler that puts a different class where the game kept, say, a
/// CameraAim local only fails 40 minutes later in clang ("incompatible pointer types"). Value types, generics and
/// anything that cannot be resolved are skipped (unknown); only plain class mismatches are reported.
/// </summary>
static class TypeCheck
{
    sealed class Null { }
    static readonly object NullRef = new Null();

    public static int Run(IEnumerable<string> paths, IEnumerable<string> searchDirs)
    {
        var resolver = new DefaultAssemblyResolver();
        foreach (var d in searchDirs) resolver.AddSearchDirectory(d);
        foreach (var p in paths) resolver.AddSearchDirectory(Path.GetDirectoryName(Path.GetFullPath(p))!);
        int bad = 0, total = 0;
        foreach (var path in paths)
        {
            var module = ModuleDefinition.ReadModule(path, new ReaderParameters { AssemblyResolver = resolver });
            foreach (var m in module.GetTypes().SelectMany(t => t.Methods).Where(m => m.HasBody))
            {
                total++;
                foreach (var err in Check(m))
                {
                    bad++;
                    Console.WriteLine($"{Path.GetFileName(path)}: {m.FullName}: {err}");
                }
            }
        }
        Console.WriteLine($"{total} methods, {bad} type mismatches");
        return bad == 0 ? 0 : 1;
    }

    static IEnumerable<string> Check(MethodDefinition m)
    {
        var errors = new List<string>();
        var ins = m.Body.Instructions;
        var seen = new Dictionary<Instruction, object?[]>();
        var work = new Stack<(Instruction, object?[])>();
        work.Push((ins[0], Array.Empty<object?>()));
        foreach (var h in m.Body.ExceptionHandlers)
        {
            work.Push((h.HandlerStart, h.HandlerType is ExceptionHandlerType.Catch or ExceptionHandlerType.Filter ? new object?[] { null } : Array.Empty<object?>()));
            if (h.FilterStart != null) work.Push((h.FilterStart, new object?[] { null }));
        }
        var guard = 0;
        while (work.Count > 0 && guard++ < 200000)
        {
            var (start, entry) = work.Pop();
            var i = start;
            var stack = new List<object?>(entry);
            while (i != null)
            {
                if (seen.TryGetValue(i, out var old))
                {
                    if (old.Length != stack.Count) break; // the stack check reports depth problems
                    var merged = old.Zip(stack, (a, b) => Same(a, b) ? a : null).ToArray();
                    if (merged.SequenceEqual(old)) break;
                    seen[i] = merged;
                    stack = merged.ToList();
                }
                else seen[i] = stack.ToArray();

                Step(m, i, stack, errors);
                var code = i.OpCode.Code;
                var fc = i.OpCode.FlowControl;
                if (code is Code.Ret or Code.Throw or Code.Rethrow or Code.Endfinally or Code.Endfilter) break;
                if (code is Code.Leave or Code.Leave_S) { work.Push(((Instruction)i.Operand, Array.Empty<object?>())); break; }
                if (fc == FlowControl.Branch) { work.Push(((Instruction)i.Operand, stack.ToArray())); break; }
                if (fc == FlowControl.Cond_Branch)
                {
                    if (i.Operand is Instruction[] targets) foreach (var t in targets) work.Push((t, stack.ToArray()));
                    else work.Push(((Instruction)i.Operand, stack.ToArray()));
                }
                i = i.Next;
            }
        }
        return errors.Distinct();
    }

    static bool Same(object? a, object? b) =>
        ReferenceEquals(a, b) || (a is TypeReference x && b is TypeReference y && x.FullName == y.FullName);

    static void Step(MethodDefinition m, Instruction i, List<object?> stack, List<string> errors)
    {
        object? Pop() { if (stack.Count == 0) return null; var v = stack[^1]; stack.RemoveAt(stack.Count - 1); return v; }
        void PopN(int n) { for (var k = 0; k < n; k++) Pop(); }
        void Push(object? v) => stack.Add(v);
        void Expect(object? value, TypeReference target, string what)
        {
            if (value is TypeReference source && !Assignable(source, target))
                errors.Add($"IL_{i.Offset:x4} {i.OpCode}: {source.FullName} where {what} is {target.FullName}");
        }

        switch (i.OpCode.Code)
        {
            case Code.Ldarg_0: case Code.Ldarg_1: case Code.Ldarg_2: case Code.Ldarg_3: case Code.Ldarg: case Code.Ldarg_S:
                Push(ArgType(m, i)); return;
            case Code.Ldloc_0: case Code.Ldloc_1: case Code.Ldloc_2: case Code.Ldloc_3: case Code.Ldloc: case Code.Ldloc_S:
                Push(Local(m, i).VariableType); return;
            case Code.Stloc_0: case Code.Stloc_1: case Code.Stloc_2: case Code.Stloc_3: case Code.Stloc: case Code.Stloc_S:
            {
                var local = Local(m, i);
                Expect(Pop(), local.VariableType, $"local V_{local.Index}");
                return;
            }
            case Code.Ldnull: Push(NullRef); return;
            case Code.Ldstr: Push(m.Module.TypeSystem.String); return;
            case Code.Ldsfld: Push(((FieldReference)i.Operand).FieldType); return;
            case Code.Ldfld: Pop(); Push(((FieldReference)i.Operand).FieldType); return;
            case Code.Stsfld: Expect(Pop(), ((FieldReference)i.Operand).FieldType, "static field " + ((FieldReference)i.Operand).Name); return;
            case Code.Stfld:
            {
                var f = (FieldReference)i.Operand;
                Expect(Pop(), f.FieldType, "field " + f.Name);
                Expect(Pop(), f.DeclaringType, "the object of " + f.Name);
                return;
            }
            case Code.Castclass: case Code.Isinst: Pop(); Push(i.Operand as TypeReference); return;
            case Code.Call: case Code.Callvirt: case Code.Newobj:
            {
                var mr = (MethodReference)i.Operand;
                for (var k = mr.Parameters.Count - 1; k >= 0; k--)
                    Expect(Pop(), mr.Parameters[k].ParameterType, $"argument {k} of {mr.DeclaringType.Name}::{mr.Name}");
                if (i.OpCode.Code == Code.Newobj) { Push(mr.DeclaringType); return; }
                if (mr.HasThis) Expect(Pop(), mr.DeclaringType, $"this of {mr.DeclaringType.Name}::{mr.Name}");
                if (mr.ReturnType.MetadataType != MetadataType.Void) Push(mr.ReturnType);
                return;
            }
            case Code.Ret:
                if (m.ReturnType.MetadataType != MetadataType.Void) Expect(Pop(), m.ReturnType, "the return value");
                return;
        }

        // Everything else: right depth, unknown types
        PopN(Pops(i, m));
        for (var k = Pushes(i); k > 0; k--) Push(null);
    }

    static TypeReference? ArgType(MethodDefinition m, Instruction i)
    {
        int index = i.OpCode.Code switch
        {
            Code.Ldarg_0 => 0, Code.Ldarg_1 => 1, Code.Ldarg_2 => 2, Code.Ldarg_3 => 3,
            _ => ((ParameterDefinition)i.Operand).Index + (m.HasThis ? 1 : 0),
        };
        if (m.HasThis)
        {
            if (index == 0) return m.DeclaringType.IsValueType ? null : m.DeclaringType;
            index--;
        }
        return index < m.Parameters.Count ? m.Parameters[index].ParameterType : null;
    }

    static VariableDefinition Local(MethodDefinition m, Instruction i) => i.OpCode.Code switch
    {
        Code.Ldloc_0 or Code.Stloc_0 => m.Body.Variables[0],
        Code.Ldloc_1 or Code.Stloc_1 => m.Body.Variables[1],
        Code.Ldloc_2 or Code.Stloc_2 => m.Body.Variables[2],
        Code.Ldloc_3 or Code.Stloc_3 => m.Body.Variables[3],
        _ => (VariableDefinition)i.Operand,
    };

    /// <summary>Only plain classes are judged; everything else counts as assignable</summary>
    static bool Assignable(TypeReference source, TypeReference target)
    {
        if (source.FullName == target.FullName) return true;
        if (!Plain(source) || !Plain(target)) return true;
        TypeDefinition? s, t;
        try { s = source.Resolve(); t = target.Resolve(); } catch { return true; }
        if (s == null || t == null || s.IsValueType || t.IsValueType) return true;
        if (t.FullName == "System.Object") return true;
        if (t.IsInterface) return true; // interface lists are not followed through generic bases
        for (var cur = s; cur != null;)
        {
            if (cur.FullName == t.FullName) return true;
            try { cur = cur.BaseType?.Resolve(); } catch { return true; }
        }
        return false;
    }

    static bool Plain(TypeReference t) =>
        !t.IsGenericParameter && !t.IsGenericInstance && !t.IsArray && !t.IsByReference && !t.IsPointer &&
        !t.ContainsGenericParameter && !t.IsValueType && t.MetadataType is MetadataType.Class or MetadataType.Object;

    // The stack check's depth rules (top-level functions of Program.cs are not reachable from here)
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
}

