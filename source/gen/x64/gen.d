module gen.x64.generator;

import std.stdio;
import std.conv;
import std.format;

import logger;

import gen.x64.output;

import kir.instr;

struct Block_Context {
	uint addr_ptr = 0;
	string[uint] locals;
}

class X64_Generator {
	X64_Code code;

	Block_Context[] ctx;

	this() {
		code = new X64_Code;
	}

	void emit_store(Store s) {

	}

	void emit_ret() {
		code.emitt("popq %rbp");
		code.emitt("ret");
	}

	void emit_instr(Instruction i) {
		if (auto alloc = cast(Alloc)i) {
			// code.emitt("nop");
		}
		else if (auto ret = cast(Return)i) {
			emit_ret();
		}
		else if (auto store = cast(Store)i) {
			emit_store(store);
		}
		else {
			logger.Fatal("x64_gen: unhandled instruction ", to!string(typeid(cast(Basic_Instruction)i)), ":\n\t", to!string(i));
		}
	}

	void emit_bb(Basic_Block bb) {
		foreach (instr; bb.instructions) {
			emit_instr(instr);
		}
	}

	void generate_func(Function func) {
		code.emit("{}:", func.name);

		code.emitt("pushq %rbp");
		code.emitt("movq %rsp, %rbp");

		ctx ~= Block_Context();

		foreach (bb; func.blocks) {
			emit_bb(bb);
		}

		// if there is no return instr
		// slap one on the end.
		if (!(cast(Return) func.last_instr())) {
			emit_ret();
		}
	}
}