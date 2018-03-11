module gen.x64.backend;

import std.stdio;
import std.path;
import std.file;
import std.process;
import std.random;
import std.conv;

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

		File[] as_files;
		// write all of these files
		// into assembly files
		// feed them into the gnu AS 
		foreach (ref code_file; output) {
			auto x64_code = cast(X64_Code) code_file;
			
			string file_name = "krug-asm-" ~ thisProcessID.to!string(36) ~ "-" ~ uniform!uint.to!string(36) ~ ".as";
			auto temp_file = File(buildPath(tempDir(), file_name), "w");
			writeln("Assembly file '", temp_file.name, "' created.");

			temp_file.write(x64_code.assembly_code);
			as_files ~= temp_file;

			writeln(x64_code.assembly_code);
		}

		string[] as_files_str;
		foreach (as_file; as_files) {
			as_files_str ~= as_file.name;
		}

		auto log_file = File("krug_compile_log.log", "w");
		string[] arg = ["as", "-c"] ~ as_files_str;

		writeln("Executing the following command: ", arg);

		auto as_pid = spawnProcess(arg, 
			std.stdio.stdin,
            std.stdio.stdout,
            log_file);
		if (wait(as_pid) != 0) {
		    writeln("Compilation failed!");
		}
	}
}
