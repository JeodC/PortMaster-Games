using System;
using Mono.Cecil;

// Rewrites an assembly with all types/methods/fields public, for use as a
// compile-time reference only
class Publicize
{
	static void Main(string[] args)
	{
		var resolver = new DefaultAssemblyResolver();
		resolver.AddSearchDirectory(System.IO.Path.GetDirectoryName(System.IO.Path.GetFullPath(args[0])));
		var asm = AssemblyDefinition.ReadAssembly(args[0], new ReaderParameters { AssemblyResolver = resolver });
		foreach (var module in asm.Modules)
		{
			foreach (var type in module.GetTypes())
			{
				if (type.IsNested) type.IsNestedPublic = true;
				else type.IsPublic = true;
				foreach (var m in type.Methods) m.IsPublic = true;
				foreach (var f in type.Fields) f.IsPublic = true;
			}
		}
		asm.Write(args[1]);
		Console.WriteLine("publicized -> " + args[1]);
	}
}
