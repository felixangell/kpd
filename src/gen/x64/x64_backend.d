module gen.x64.backend;

import std.stdio;
import std.path;
import std.file;
import std.process;
import std.random;
import std.conv;

import cflags;
import kir.ir_mod;

import gen.backend;
import gen.x64.output;
import gen.x64.generator;
import gen.x64.mangler;
import gen.x64.link;

/*
	the x64 backend generates x86_64 assembly. 
*/
class X64_Backend : Code_Generator_Backend {
	X64_Code code_gen(Kir_Module mod) {
		auto gen = new X64_Generator;

		// is this necessary
		version(OSX) {
			gen.code.emit(".macosx_version_min 10, 16");
		}

		gen.emit_mod(mod);

		// hack
		// generate a main function for us to
		// enter, this only works for single
		// module programs atm because if 
		// we add more modules then they will
		// all have a main function generated

		string entry_label = "main";
		version (OSX) {
			entry_label = "_main";
		}
		else version (Posix) {
			entry_label = "_start";
		}

		gen.code.emit(".global {}", entry_label);
		gen.code.emit("{}:", entry_label);
		gen.code.emitt("pushq %rbp");
		gen.code.emitt("movq %rsp, %rbp");

		{
			auto main_func = mod.get_function("main");
			if (main_func !is null) {
				gen.code.emitt("call {}", mangle(main_func));
			}			
		}

		gen.code.emitt("popq %rbp");

		version (OSX) {
			gen.code.emitt("ret");
		}
		else version (Posix) {
			// http://blog.rchapman.org/posts/Linux_System_Call_Table_for_x86_64/
			// invoke sys_exit

			// rax is the return value of the function
			// invoked from the main entry point
			// store this for later
			gen.code.emitt("pushq %rax");

			// invoke the sys_exit syscall (60)
			gen.code.emitt("movq $60, %rax");

			// the exit code (param to the sys_exit syscall)
			// is the value in rsi, which was thej return value
			// from the function called from this main entry
			// point
			gen.code.emitt("popq %rdi");

			// invoke the syscall
			gen.code.emitt("syscall");
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
			auto temp_file = File(file_name, "w");
			writeln("Assembly file '", temp_file.name, "' created.");

			temp_file.write(x64_code.assembly_code);
			as_files ~= temp_file;
			temp_file.close();

			foreach (i, line; x64_code._assembly_code) {
				if (line.length == 0) {
					continue;
				}
				writefln("%04d:\t\t%s", i, line);
			}
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

		link_objs(obj_file_paths, OUT_NAME);

		// delete object files and assembly files
		foreach (as_file; as_files) {
			remove(as_file.name);
		}

		foreach (obj_file; obj_file_paths) {
			remove(obj_file);
		}
	}
}
