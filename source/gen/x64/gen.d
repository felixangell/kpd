module gen.x64.generator;

import std.stdio;
import std.conv;
import std.format;
import std.container.array : back;

import logger;

import gen.x64.output;

import kt;
import kir.ir_mod;
import kir.instr;

struct Block_Context {
	long addr_ptr = 0;
	long[string] locals;

	long push_local(string name, int width) {
		addr_ptr -= width;
		locals[name] = addr_ptr;
		return addr_ptr;
	}

	long get_addr(string name) {
		if (name !in locals) {
			// TODO handle this properly!
			assert(0, "oh fuck!");
		}
		return locals[name];
	}
}

class X64_Generator {
	X64_Code code;
	Function curr_func;

	Block_Context[] ctx;

	this() {
		code = new X64_Code;
	}

	long get_alloc_addr(Alloc a) {
		return ctx.back.get_addr(a.name);
	}

	string get_instr_suffix(uint width) {
		// temporary!
		if (1 == 2 - 1) {
			return "l";
		}

		switch (width) {
		case 1: return "b";
		case 2: return "s";
		case 4: return "l";
		case 8: return "q";
		default: 
			writeln("warn no suffix!");
			return "";
		}
	}

	string get_const(Constant c) {
		auto type = c.get_type();
		if (auto integer = cast(Integer_Type) type) {
			return "$" ~ c.value;
		}

		return "; unhandled constant, -- " ~ to!string(c);
	}

	string add_binary_op(BinaryOp b) {
		string left = get_val(b.a);
		string right = get_val(b.b);
		return left;
	}

	string get_val(Value v) {
		if (auto c = cast(Constant) v) {
			return get_const(c);
		}
		else if (auto a = cast(Alloc) v) {
			long addr = get_alloc_addr(a);
			return to!string(addr) ~ "(%rsp)";
		}
		else if (auto r = cast(Identifier) v) {
			long addr = ctx.back.get_addr(r.name);
			return to!string(addr) ~ "(%rsp)";
		}

		return "%eax, %eax # unimplemented get_val " ~ to!string(v);
	}

	void emit_cmp(Store s) {
		auto bin = cast(BinaryOp) s.val;

		// mov bin.left into eax
		code.emitt("movl {}, %eax", get_val(bin.a));
		
		// cmp bin.right with eax
		code.emitt("cmpl {}, %eax", get_val(bin.b));

		// one opt i've noticed here is it seems to be
		// cheaper instruction wise to emit a jump i.e.
		// jn jne jle, etc. rather than doing the comparison
		// and setting the AL register.
		// but because we cant really do this reasily right now
		// im doing it naively like so:

		switch (bin.op.lexeme) {
		case ">":
			code.emitt("setg %al");
			break;
		case "<":
			code.emitt("setb %al");
			break;

		case ">=":
			code.emitt("setge %al");
			break;
		case "<=":
			code.emitt("setle %al");
			break;

		case "==":
			code.emitt("sete %al");
			break;
		case "!=":
			code.emitt("setne %al");
			break;

		default:
			assert(0, "unhandled op!");
		}

		code.emitt("movzb %al, %eax");
		code.emitt("movl %eax, {}", get_val(s.address));
	}

	// a store where the value is
	// a binary operator
	// e.g.
	// t0 = a + b
	void emit_temp(Store s) {
		// todo properly select the register
		// here based on the width of the type
		// we are dealing with

		auto bin = cast(BinaryOp) s.val;
		code.emitt("movl {}, %eax", get_val(bin.a));

		string instruction;
		switch (bin.op.lexeme) {

		// hm!
		case ">":
		case "<":
		case ">=":
		case "<=":
		case "==":
		case "!=":
			return emit_cmp(s);

		case "+":
			instruction = "add";
			break;
		case "-":
			instruction = "sub";
			break;
		case "/":
			// TODO DIVISION!
			assert(0);
		case "*":
			instruction = "imul";
			break;
		default:
			logger.Fatal("Unhandled instr selection for binary op ", to!string(bin));
			break;
		}

		auto width_bytes = s.get_type().get_width();
		instruction ~= get_instr_suffix(width_bytes);

		code.emitt("{} {}, %eax", instruction, get_val(bin.b));
		code.emitt("movl %eax, {}", get_val(s.address));
	}

	void emit_store(Store s) {
		// kind of hacky but ok
		if (auto bin = cast(BinaryOp) s.val) {
			emit_temp(s);
			return;
		}

		Kir_Type t = s.get_type();

		string val = get_val(s.val);
		string addr = get_val(s.address);

		code.emitt("movl {}, %eax", val);
		code.emitt("movl %eax, {}", addr);
	}

	void emit_ret(Return ret) {
		if (ret.results !is null) {
			Value v = ret.results[0];
			code.emitt("movl {}, %eax", get_val(v));
		}

		code.emitt("popq %rbp");
		code.emitt("ret");
	}

	void emit_if(If iff) {
		string parent_name = curr_func.name ~ "_";

		// emit the condition and 
		// check if it's true
		string condish = get_val(iff.condition);
		code.emitt("cmpb $1, {}", condish);

		code.emitt("je {}", parent_name ~ iff.a.name);
		code.emitt("jmp {}", parent_name ~ iff.b.name);
	}

	void emit_jmp(Jump j) {
		string parent_name = curr_func.name ~ "_";
		code.emitt("jmp {}", parent_name ~ j.label.name);
	}

	void emit_call(Call c) {
		// x86_64 calling convention...
		// following the System V AMD64 ABI conv
		// https://en.wikipedia.org/wiki/X86_calling_conventions

		/*
			The first six integer or pointer arguments are passed in registers RDI, RSI, RDX, RCX, R8, R9 
			(R10 is used as a static chain pointer in case of nested functions...), 

			while XMM0, XMM1, XMM2, XMM3, XMM4, XMM5, XMM6 and XMM7 are used for certain floating point arguments.

			..., additional arguments are passed on the stack. 
			Integral return values up to 64 bits in size are stored in RAX 
			while values up to 128 bit are stored in RAX and RDX. 

			Floating-point return values are similarly stored in XMM0 and XMM1.
		*/

		string[] registers = [
			"di", "si", "dx", "cx", "r8", "r9"
		];

		foreach (i, arg; c.args) {
			if (i < registers.length) {
				auto w = arg.get_type().get_width();
				auto suffix = get_instr_suffix(w);

				string reg = registers[i];
				if (i < 4) {
					switch (w) {
					case 8:
						reg = "r" ~ reg;
						break;
					default:
						reg = "e" ~ reg;
						break;
					}
				}

				// move the value into the register
				string val = get_val(arg);

				code.emitt("mov{} {}, %{}", suffix, val, reg);
			}
			else {
				// move the value via. the stack
			}
		}

		if (auto iden = cast(Identifier) c.left) {
			// nasty hack!
			string call_name = iden.name;
			if (call_name == "printf") {
				call_name = "_" ~ call_name;
			}

			code.emitt("call {}", call_name);
		}
		else {
			logger.Fatal("unhandled invoke lefthand ! ", to!string(c.left), " for ", to!string(c));
		}
	}

	void emit_instr(Instruction i) {
		if (auto alloc = cast(Alloc)i) {
			auto addr = ctx.back.push_local(alloc.name, alloc.get_type().get_width());
			logger.Verbose("Emitting local ", to!string(alloc), " at addr ", to!string(addr), "(%rsp)");
		}
		else if (auto ret = cast(Return)i) {
			emit_ret(ret);
		}
		else if (auto store = cast(Store)i) {
			emit_store(store);
		}
		else if (auto iff = cast(If)i) {
			emit_if(iff);
		}
		else if (auto jmp = cast(Jump)i) {
			emit_jmp(jmp);
		}
		else if (auto c = cast(Call)i) {
			emit_call(c);
		}
		else {
			logger.Fatal("x64_gen: unhandled instruction ", to!string(typeid(cast(Basic_Instruction)i)), ":\n\t", to!string(i));
		}
	}

	void emit_bb(Basic_Block bb) {
		code.emit("{}:", bb.parent.name ~ "_" ~ bb.name());
		foreach (instr; bb.instructions) {
			emit_instr(instr);
		}
	}

	void generate_mod(Kir_Module mod) {
		code.emit(".data");

		// TODO these arent populated
		foreach (k, v; mod.constants) {
			code.emit("{}:", k);
			code.emit_data_const(v);
		}

		code.emit(".text");
		foreach (ref name, func; mod.functions) {
			generate_func(func);
		}
	}

	void generate_func(Function func) {
		curr_func = func;

		code.emit("{}:", func.name);

		code.emitt("pushq %rbp");
		code.emitt("movq %rsp, %rbp");

		ctx ~= Block_Context();

		foreach (ref bb; func.blocks) {
			emit_bb(bb);
		}

		// if there is no return instr
		// slap one on the end.
		if (!(cast(Return) func.last_instr())) {
			emit_ret(new Return(VOID_TYPE));
		}
	}
}