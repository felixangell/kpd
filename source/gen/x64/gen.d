module gen.x64.generator;

import std.stdio;
import std.conv;
import std.format;

import logger;

import gen.x64.output;

import kt;
import kir.instr;

struct Block_Context {
	uint addr_ptr = 0;
	uint[string] locals;

	void push_local(string name, int width) {
		addr_ptr += width;
		locals[name] = addr_ptr;
	}

	uint get_addr(string name) {
		if (name !in locals) {
			assert(0, "oh fuck!");
		}
		return locals[name];
	}
}

class X64_Generator {
	X64_Code code;

	Block_Context[] ctx;

	this() {
		code = new X64_Code;
	}

	uint get_alloc_addr(Alloc a) {
		return ctx.back.get_addr(a.name);
	}

	uint get_addr(Value addr) {
		if (auto alloc = cast(Alloc) addr) {
			return get_alloc_addr(alloc);
		}

		assert(0, "gen: unhandled addr in gen_addr");
	}

	string get_instr_suffix(uint width) {
		final switch (width) {
		case 1: return "b";
		case 2: return "s";
		case 4: return "l";
		case 8: return "q";
		}

		assert(0, "no suffix for " ~ to!string(width));
	}

	string get_val(Value v) {
		return "WHAT";
	}

	void emit_store(Store s) {
		Kir_Type t = s.get_type();

		code.emitt("mov{} {}, {}", 
			get_instr_suffix(t.get_width()), 
			get_val(s.val), 
			get_val(s.address));
	}

	void emit_ret() {
		code.emitt("popq %rbp");
		code.emitt("ret");
	}

	void emit_instr(Instruction i) {
		if (auto alloc = cast(Alloc)i) {
			ctx.back.push_local(alloc.name, alloc.get_type().get_width());
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