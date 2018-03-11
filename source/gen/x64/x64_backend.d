module gen.x64.backend;

import std.stdio;

import kir.ir_mod;

import gen.backend;
import gen.x64.output;
import gen.x64.generator;

/*
	the x64 backend generates x86_64 assembly. 
*/
class X64_Backend : Code_Generator_Backend {
	X64_Code code_gen(Kir_Module mod) {
		auto gen = new X64_Generator;
		foreach (ref name, func; mod.functions) {
			gen.generate_func(func);
		}
		return gen.code;
	}

	void write(Generated_Output[] output) {
		writeln("- we've got ", output.length, " generated files.");

		// write all of these files
		// into assembly files
		// feed them into the gnu AS 
		foreach (ref code_file; output) {
			auto x64_code = cast(X64_Code) code_file;
			writeln(x64_code.assembly_code);
		}
	}
}
