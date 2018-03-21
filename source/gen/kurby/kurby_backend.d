module gen.kurby.backend;

import std.stdio;
import std.path;
import std.file;
import std.process;
import std.random;
import std.conv;

import kir.ir_mod;

import gen.backend;
import gen.kurby.output;
import gen.kurby.generator;

// this hooks into the virtual machine which
// is separately implemented in C
extern (C) bool execute_program(size_t entry_addr, size_t instruction_count, ubyte* program);

class Kurby_Backend : Code_Generator_Backend {
	Kurby_Byte_Code code_gen(Kir_Module mod) {
		auto gen = new Kurby_Generator;
		gen.generate_mod(mod);
		return gen.code;
	}

	void write(Generated_Output[] output) {
		
	}
}
