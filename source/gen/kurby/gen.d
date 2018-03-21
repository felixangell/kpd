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

	this() {
		code = new Kurby_Byte_Code;
	}

	void gen_func(Function func) {
		uint func_addr = code.program_index;
		code.func_addr_reg[func.name] = func_addr;
		logger.Verbose("func '", to!string(func.name), "' at addr: ", to!string(func_addr));

		code.emit(encode(OP.ENTR));
		
		code.emit(encode(OP.RET));
	}

	void generate_mod(Kir_Module mod) {
		// todo global variables.
		foreach (ref name, func; mod.functions) {
			gen_func(func);	
		}
	}
}