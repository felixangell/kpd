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

		gen.generate_mod(mod);

		// hack
		// generate a main function for us to
		// enter, this only works for single
		// module programs atm because if 
		// we add more modules then they will
		// all have a main function generated

		gen.code.emit(".global _main");
		gen.code.emit("_main:");
		gen.code.emitt("pushq %rbp");
		gen.code.emitt("movq %rsp, %rbp");
		gen.code.emitt("call {}", mod.get_function("main").name);
		gen.code.emitt("movl $0, %eax");
		gen.code.emitt("popq %rbp");
		gen.code.emitt("ret");

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
			auto temp_file = File(file_name, "w");
			writeln("Assembly file '", temp_file.name, "' created.");

			temp_file.write(x64_code.assembly_code);
			as_files ~= temp_file;
			temp_file.close();

			writeln(x64_code.assembly_code);
		}

		string[] obj_file_paths;

		// run the assembler on each assembly file
		// individually.
		foreach (as_file; as_files) {
			string obj_file_path = baseName(as_file.name, ".as") ~ ".o";

			string[] args = ["as", as_file.name, "-o", obj_file_path];
			writeln("Executing the following command: ", args);

			auto as_pid = execute(args);
			if (as_pid.status != 0) {
				writeln("Assembler failed:\n", as_pid.output);
				continue;
			}

			obj_file_paths ~= obj_file_path;
		}

		// run the linker!

		string obj_files;
		foreach (i, obj; obj_file_paths) {
			if (i > 0) obj_files ~= " ";
			obj_files ~= obj;
		}

		string[] link_flags;
		version (OSX) {
			link_flags ~= "-macosx_version_min";
			link_flags ~= "10.16";
			link_flags ~= "-lsystem";
		}

		auto linker_args = ["ld"] ~ link_flags ~ [obj_files, "-o", "a.out"];
		writeln("Running linker", linker_args);

		auto ld_pid = execute(linker_args);
		if (ld_pid.status != 0) {
			writeln("Linker failed:\n", ld_pid.output);
		}

		// delete object files and assembly files
		foreach (as_file; as_files) {
			remove(as_file.name);
		}

		foreach (obj_file; obj_file_paths) {
			remove(obj_file);
		}
	}
}
