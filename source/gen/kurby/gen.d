module gen.kurby.generator;

import std.stdio;
import std.conv;
import std.format;
import std.container.array : back;

import ast;
import logger;
import krug_module;

import logger;

import gen.kurby.output;
import gen.kurby.opcode;

import kt;
import kir.ir_mod;
import kir.instr;

T instanceof(T)(Object o) if (is(T == class)) {
	return cast(T) o;
}

class Kurby_Generator {
	Kurby_Byte_Code code;

	uint program_index = 0;
	ubyte[] program;

	uint[string] func_addr_reg;

	this() {
	}

	uint emit(Encoded_Instruction instr) {
		auto idx = program_index;
		program_index += instr.data.length;
		program ~= instr.data;
		return idx;
	}

	void rewrite(uint index, Encoded_Instruction instr) {
		foreach (idx, val; instr.data) {
			program[index + idx] = val;
		}
	}

	void gen_func(Function func) {
		uint func_addr = program_index;
		func_addr_reg[func.name] = func_addr;
		logger.Verbose("func '", to!string(func.name), "' at addr: ", to!string(func_addr));

		emit(encode(OP.ENTR));
		// TODO
		emit(encode(OP.RET));
	}

	void generate_mod(Kir_Module mod) {
		// todo global variables.

		foreach (ref name, func; mod.functions) {
			gen_func(func);	
		}
	}
}