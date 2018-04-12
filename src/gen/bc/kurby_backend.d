module gen.bc.backend;

import std.stdio;
import std.path;
import std.file;
import std.process;
import std.random;
import std.conv;

import logger;

import kir.ir_mod;
import kir.instr;

import gen.backend;
import gen.bc.output;
import gen.bc.generator;
import gen.bc.opcode;

// this hooks into the virtual machine which
// is separately implemented in C
extern (C) bool execute_program(size_t entry_addr, size_t instruction_count, ubyte* program);

class Bytecode_Driver : Code_Generator_Backend {
	Function main_func;

	Bytecode code_gen(IR_Module mod) {
		auto gen = new Bytecode_Generator;
		gen.emit_mod(mod);
		auto f = mod.get_function("main");
		if (f !is null) {
			main_func = f;
		}
		return gen.code;
	}

	void write(Generated_Output[] output) {
		ubyte[] final_program;
		ulong main_addr = 0;

		foreach (ref o; output) {
			auto bc = cast(Bytecode) o;
			final_program ~= bc.program;

			if (main_func.name in bc.func_addr_reg) {
				main_addr = bc.func_addr_reg[main_func.name];
			}
		}

		if (final_program.length == 0) {
			logger.verbose("Nothing to execute");
			return;
		}

		logger.verbose("Executing ", to!string(final_program.length), " instructions from addr ", to!string(main_addr));
		execute_program(main_addr, final_program.length, &final_program[0]);
	}
}
