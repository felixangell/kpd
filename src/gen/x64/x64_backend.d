module gen.x64.backend;

import std.stdio;
import std.path;
import std.file;
import std.process;
import std.random;
import std.conv;

import cflags;
import logger;
import kir.ir_mod;

import gen.backend;
import gen.x64.instr;
import gen.x64.asm_writer;
import gen.x64.asm_file;
import gen.x64.generator;
import gen.x64.mangler;
import gen.x64.link;

// parses the the stdout/err? from the
// asm program.
void parse_asm_out(string asm_out) {
	// TODO?
}

/*
	the x64 backend generates x86_64 assembly. 

	// TODO move all generation out of here
	// because its mostly for hacky reasons!
*/
class X64_Backend : Code_Generator_Backend {
	X64_Assembly code_gen(IR_Module mod) {
		auto gen = new X64_Generator;
		gen.emit_mod(mod);
		return gen.writer;
	}

	void write(Generated_Output[] output) {
		writeln("- we've got ", output.length, " generated files.");

		File[] as_files;
		scope(exit) {
			// we dont want to remove
			// the assembly files if thats
			// all we're spitting out
			if (OUT_TYPE != Output_Type.Assembly) {
				foreach (as_file; as_files) {
					remove(as_file.name);
				}
			}
		}

		// write all of these files
		// into assembly files
		// feed them into the gnu AS 
		foreach (ref code_file; output) {
			auto x64_code = cast(X64_Assembly) code_file;
			
			string file_name = "krug-asm-" ~ thisProcessID.to!string(36) ~ "-" ~ uniform!uint.to!string(36) ~ ".as";
			auto temp_file = File(file_name, "w");
			writeln("Assembly file '", temp_file.name, "' created.");

			temp_file.write(x64_code.assembly_code);
			as_files ~= temp_file;
			temp_file.close();

			if (VERBOSE_LOGGING) x64_code.dump_to_stdout();
		}

		if (OUT_TYPE == Output_Type.Assembly) {
			return;
		}

		bool assembler_failed = false;
		string[] obj_file_paths;
		scope(exit) {
			// likewise we dont want to delete the object
			// files if we are being asked to spit out object files
			if (OUT_TYPE != Output_Type.Object_Files) {
				foreach (obj_file; obj_file_paths) {
					remove(obj_file);
				}
			}
		}

		// run the assembler on each assembly file
		// individually.
		foreach (as_file; as_files) {
			string obj_file_path = baseName(as_file.name, ".as") ~ ".o";

			string[] args = ["as", as_file.name, "-o", obj_file_path];
			version (OSX) {} else {
				args ~= "-f";				
			}

			writeln("Assembler running: ", args);

			auto as_pid = execute(args);
			if (as_pid.status != 0) {
				logger.error("Assembler failed:\n", as_pid.output);
				assembler_failed = true;
			}
			else {
				writeln("Assembler notes:\n", as_pid.output);


				parse_asm_out(as_pid.output);
			}

			obj_file_paths ~= obj_file_path;
		}

		// dont try and link if the assembler
		// has failed.
		if (assembler_failed) {
			return;
		}

		// dont link into an executable
		// spit out the assembly files and that's it
		if (OUT_TYPE == Output_Type.Object_Files) {
			return;
		}

		// REALLY IMPORTANT NOTE:
		// if we have c_functions anywhere
		// we link via GCC/clang instead!
		// this is kind of messy but for now itll do

		link_objs(obj_file_paths, OUT_NAME);
	}
}
