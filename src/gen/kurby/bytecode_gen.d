module gen.kurby.generator;

import std.stdio;
import std.conv;
import std.format;
import std.container.array;

import ast;
import logger;
import krug_module;
import sema.type;

import logger;

import gen.kurby.output;
import gen.kurby.opcode;

import kir.ir_mod;
import kir.instr;

T instanceof(T)(Object o) if (is(T == class)) {
	return cast(T) o;
}

class Kurby_Generator {
	IR_Module mod;
	Kurby_Byte_Code code;

	// todo
	uint[string] locals;
	uint local_ptr = 0;

	uint[string] bb_label_addr;

	this() {
		code = new Kurby_Byte_Code;
	}

	void emit_alloc(Alloc a) {
		// for now we just push a zero on the stack
		code.emit(encode(OP.PSHI, 0));

		// which is allocated
		code.emit(encode(OP.ALLOCI));

		locals[a.name] = local_ptr;
		writeln("Stored ", a.name, " at local addr", local_ptr);

		auto width = a.get_type().get_width();
		// FIXME some types are still void here
		// from the inference phases, for now this
		// is a silly hack to assume things are 4 bytes
		if (width == 0) width = 4; // HACK for void leaks
		local_ptr += width;
	}

	void emit_push_const(Constant c) {
		if (auto integer = cast(Type) c.get_type()) {
			switch (integer.get_width()) {
			case 4:
				uint val = to!uint(c.value);
				code.emit(encode(OP.PSHI, val));
				break;
			default:
				assert(0, "unhandled integer width");
			}
		}
		else {
			logger.fatal("unhandled constant type ", to!string(c.get_type()));
		}
	}

	void emit_binary_value(Binary_Op b) {
		emit_value(b.a);
		emit_value(b.b);

		switch (b.op) {
		case "+":
			code.emit(encode(OP.ADDI));
			break;
		case "-":
			code.emit(encode(OP.SUBI));
			break;
		case "*":
			code.emit(encode(OP.MULI));
			break;

		case ">":
			code.emit(encode(OP.GTRI));
			break;

		default:
			assert(0, "unhandled expression!" ~ to!string(b.op));
		}
	}

	void emit_identifier(Identifier i) {
		code.emit(encode(OP.LDI, locals[i.name]));
	}

	void emit_value(Value v) {
		if (auto c = cast(Constant) v) {
			emit_push_const(c);
		}
		else if (auto b = cast(Binary_Op) v) {
			emit_binary_value(b);
		}
		else if (auto i = cast(Identifier) v) {
			emit_identifier(i);
		}
		else {
			logger.fatal("unhandled value ", to!string(v));
		}
	}

	void emit_store(Store s) {
		emit_value(s.val);
		if (auto alloc = cast(Alloc) s.address) {
			assert(alloc.name in locals);
			auto addr = locals[alloc.name];
			code.emit(encode(OP.STRI, addr));
		}
	}

	Label[uint] rewrites;
	void rewrite_jump_later(uint instr_addr, Label label) {
		// TODO
	}

	string[uint] func_call_rewrites;
	void rewrite_call_later(uint call_addr, string func_name) {
		// TODO
	}

	void emit_if(If i) {
		emit_value(i.condition);

		auto true_br = code.emit(encode(OP.JE, 0));
		auto false_br = code.emit(encode(OP.JNE, 0));

		rewrite_jump_later(true_br, i.a);
		rewrite_jump_later(false_br, i.b);
	}

	void emit_jump(Jump j) {
		// fixme with just a normal jump instr
		code.emit(encode(OP.PSHI, 1));
		auto jmp = code.emit(encode(OP.JE, 0));
		rewrite_jump_later(jmp, j.label);
	}

	void emit_ret(Return ret) {
		if (ret.results !is null && ret.results.length > 0) {
			emit_value(ret.results[0]);
		}
		code.emit(encode(OP.RET));
	}

	void emit_call(Call c) {
		// fixme
		if (auto iden = cast(Identifier) c.left) {
			auto call_addr = code.emit(encode(OP.CALL, 0));
			rewrite_call_later(call_addr, iden.name);
		}
	}

	void gen_bb(Basic_Block bb) {
		bb_label_addr[bb.name()] = code.program_index;

		foreach (instr; bb.instructions) {
			if (auto a = cast(Alloc) instr) {
				emit_alloc(a);
			}
			else if (auto s = cast(Store) instr) {
				emit_store(s);
			}
			else if (auto iff = cast (If) instr) {
				emit_if(iff);
			}
			else if (auto jmp = cast(Jump) instr) {
				emit_jump(jmp);
			}
			else if (auto ret = cast(Return) instr) {
				emit_ret(ret);
			}
			else if (auto c = cast(Call) instr) {
				emit_call(c);
			}
			else {
				logger.fatal("Unhandled instruction ", to!string(instr));
			}
		}
	}

	void gen_func(Function func) {
		uint func_addr = code.program_index;
		code.func_addr_reg[func.name] = func_addr;
		logger.verbose("func '", to!string(func.name), "' at addr: ", to!string(func_addr));

		code.emit(encode(OP.ENTR));
		foreach (bb; func.blocks) {
			gen_bb(bb);
		}

		// re-write all the jump instructions
		foreach (instr_addr, label; rewrites) {
			uint label_addr = bb_label_addr[label.name];
			auto op = code.get_op(instr_addr);
			code.rewrite(instr_addr, encode(op, label_addr));
		}

		foreach (instr_addr, func_name; func_call_rewrites) {
			assert(func_name in code.func_addr_reg);
			
			uint func_addr = code.func_addr_reg[func_name];

			auto op = code.get_op(instr_addr);
			code.rewrite(instr_addr, encode(op, func_addr));
		}

		code.emit(encode(OP.RET));
	}

	void emit_mod(IR_Module mod) {
		this.mod = mod;
		// todo global variables.
		foreach (ref name, func; mod.functions) {
			gen_func(func);	
		}
	}
}