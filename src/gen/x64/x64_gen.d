module gen.x64.generator;

import std.stdio;
import std.conv;
import std.format;
import std.container.array;
import std.range.primitives;
import std.bitmanip : bitfields, FloatRep, DoubleRep;
import std.typecons : tuple, Tuple;
import std.ascii : isUpper;
import std.algorithm.searching : countUntil;
import std.math : log2;
import std.process;
import std.random;

import logger;

import sema.type;

import gen.x64.asm_file;
import gen.x64.mangler;
import gen.x64.asm_writer;
import gen.x64.instr;

import kir.ir_mod;
import kir.instr;
import kir.block_ctx;

X64_Register[] SYS_V_CALL_CONV_REG;
X64_Register[] SYS_V_CALL_CONV_REG_FLOATS;

Reg get_reg(X64_Register val) {
	return new Reg(val);
}

static this() {
	SYS_V_CALL_CONV_REG = [
		X64_Register.DIL,
		X64_Register.SIL,
		X64_Register.DL,
		X64_Register.CL,
		X64_Register.R8b,
		X64_Register.R9b,
	];

	SYS_V_CALL_CONV_REG_FLOATS = [
	// TODO
	];
}

Const make_const(T)(T val) {
	return new Const(to!string(val));
}

/*
	general notes for x64 code generation
	these are things that i read or see on the way
	they may not be the best practices or the fastest
	most efficient way to do something but here we go:

	- 
*/
class X64_Generator {
	IR_Module mod;
	X64_Assembly_Writer writer;
	Function curr_func;

	Block_Context curr_ctx;

	this() {
		writer = new X64_Assembly_Writer;
	}

	// gets the address of the given
	// alloc in the current block context
	Tuple!(long, int) get_alloc_addr(Alloc a) {
		return curr_ctx.get_addr(a.name);
	}
	Tuple!(long, int) get_alloc_addr_by_name(string name) {
		return curr_ctx.get_addr(name);
	}

	Memory_Location get_const(Constant c) {
		auto type = c.get_type();
		if (auto integer = cast(Integer) type) {
			return make_const(c.value);
		}
		else if (auto floating = cast(Floating) type) {
			// todo mangle properly?
			string name = "_FC_" ~ thisProcessID.to!string(36) ~ "_" ~ uniform!uint.to!string(36);
			emit_data_const(name, c);
			return new Address(name, get_reg(X64_Register.RIP));
		}

		logger.fatal("unhandled constant, -- " ~ to!string(c));
		assert(0);
	}

	// FIXME
	// we're hoping this is a constant...
	void emit_data_const(string name, Value v) {
		auto c = cast(Constant) v;
		if (!c) {
			logger.fatal("emit_data_const: unhandled value ", to!string(v));
		}

		string constant_type = type_name(c.get_type().get_width());

		// we can just set the value for most constants
		string constant_val = c.value;

		// floats we have to convert the floating value
		// into its float representation and spit it out
		// as an integer constant.
		if (auto f = cast(Floating) c.get_type()) {
			final switch (f.get_width()) {
			case 4:
				FloatRep flt_rep;
				flt_rep.value = to!float(c.value);
				uint int_value = *(cast(uint*)(&flt_rep));
				constant_val = to!string(int_value);
				break;
			case 8:
				DoubleRep dbl_rep;
				dbl_rep.value = to!float(c.value);
				ulong int_value = *(cast(ulong*)(&dbl_rep));
				constant_val = to!string(int_value);
				break;
			}
		}
		else if (c.get_type().cmp(new Pointer(get_int(false, 8)))) {
			constant_type = "asciz";
		}
		// TODO pascal style string i.e the struct { len, ptr_to_raw_str }

		// data constants are written
		// in the data segment. this is restored
		// back to text.
		writer.set_segment(Segment.Data);

		writer.emit("{}:", name);
		writer.emitt(".{} {}", constant_type, constant_val);

		// store the type size in the writers constant map thingy
		// for later refernecing. this is so the x64 writer can
		// infer the instructions suffix
		constant_sizes[name] = c.get_type().get_width();

		// restore back to the text segment.
		writer.set_segment(Segment.Text);
	}

	Memory_Location add_binary_op(Binary_Op b) {
		auto left = get_val(b.a);
		get_val(b.b);
		return left;
	}

	Memory_Location get_index_addr(Index i) {
		// we get the address of the array
		// we have to offset it by the value
		auto v = get_val(i.index);
		writer.mov(v, get_reg(X64_Register.R9));

		if (auto addr = cast(Address) get_val(i.addr)) {
			addr.index = get_reg(X64_Register.R9);
			addr.scale = i.get_type().get_width();
			return addr;
		}

		assert(0);
	}

	Memory_Location build_unary_op(Unary_Op u) {
		Memory_Location v = get_val(u.v);
		switch (u.op.lexeme) {
		case "!":
			writer.mov(v, get_reg(X64_Register.AL));
			writer.xor(make_const(1), get_reg(X64_Register.AL));
			return get_reg(X64_Register.AH);
		default:
			logger.fatal("unhandled unary op " ~ to!string(u));
			assert(0);
		}
	}

	Memory_Location build_addr_of(Addr_Of a) {
		Memory_Location v = get_val(a.v);
		// leaq v, rax
		writer.lea(v, get_reg(X64_Register.R10b));
		return get_reg(X64_Register.R10b);
	}

	Memory_Location build_deref(Deref d) {
		Memory_Location v = get_val(d.v);
		writer.mov(v, get_reg(X64_Register.R10b));
		return new Address(get_reg(X64_Register.R10b));
	}

	Memory_Location build_gep(Get_Element_Pointer g) {
		Memory_Location v = get_val(g.addr);
		auto addr = cast(Address) v;
		if (addr is null) {
			assert(0, "weird value for gep");
		}

		addr.set_width(g.get_width());

		if (g.scale == 0) {
			// set the offs to the index
			addr.offs = g.index;
			return addr;
		}

		// otherwise the addressing mode
		// uses scale index base.

		writer.mov(make_const(g.index), get_reg(X64_Register.R14b));
		addr.index = get_reg(X64_Register.R14b);
		addr.scale = g.scale;

		return addr;
	}

	Memory_Location get_val(Value v) {
		if (auto c = cast(Constant) v) {
			return get_const(c);
		}
		else if (auto a = cast(Alloc) v) {
			auto val = get_alloc_addr(a);
			auto addr = new Address(val[0], get_reg(X64_Register.SPL));
			addr.set_width(val[1]);
			return addr;
		}
		else if (auto r = cast(Identifier) v) {
			// first check if this is a param
			auto index = curr_ctx.parent.params.countUntil!("a.name == b")(r.name);
			if (index != -1) {
				auto arg_index = index;
				auto val = curr_ctx.get_addr("__arg_" ~ to!string(arg_index));
				auto addr = new Address(val[0], get_reg(X64_Register.SPL));
				addr.set_width(val[1]);
				return addr;
			}

			auto val = get_alloc_addr_by_name(r.name);
			if (val[0] != -1) {
				auto addr = new Address(val[0], get_reg(X64_Register.SPL));
				addr.set_width(val[1]);
				return addr;
			}

			// look for the value in the globals.
			// if it is, it's a label so we can just spit
			// out the name?
			if (r.name in mod.constants) {
				// FIXME
				// TODO get the type width here
				return new Address(r.name, get_reg(X64_Register.RIP));
			}

			assert(0);
		}
		else if (auto c = cast(Constant_Reference) v) {
			return new Address(c.name, get_reg(X64_Register.RIP));
		}
		else if (auto u = cast(Unary_Op) v) {
			return build_unary_op(u);
		}
		else if (auto i = cast(Call) v) {
			emit_call(i);
			return get_reg(X64_Register.AL);
		}
		else if (auto idx = cast(Index) v) {
			return get_index_addr(idx);
		}
		else if (auto addr = cast(Addr_Of) v) {
			return build_addr_of(addr);
		}
		else if (auto deref = cast(Deref) v) {
			return build_deref(deref);
		}
		else if (auto gep = cast(Get_Element_Pointer) v) {
			return build_gep(gep);
		}

		logger.fatal("unimplemented get_val " ~ to!string(v) ~ " ... " ~ to!string(typeid(v)));
		assert(0);
	}

	void emit_cmp(Store s) {
		auto bin = cast(Binary_Op) s.val;

		// mov bin.left into eax
		writer.mov(get_val(bin.a), get_reg(X64_Register.AL));
		
		// cmp bin.right with eax
		writer.cmp(get_val(bin.b), get_reg(X64_Register.AL));

		// one opt i've noticed here is it seems to be
		// cheaper instruction wise to emit a jump i.e.
		// jn jne jle, etc. rather than doing the comparison
		// and setting the AL register.
		// but because we cant really do this reasily right now
		// im doing it naively like so:

		switch (bin.op) {
		case ">":
			writer.setg(get_reg(X64_Register.AL));
			break;
		case "<":
			writer.setb(get_reg(X64_Register.AL));
			break;

		case ">=":
			writer.setge(get_reg(X64_Register.AL));
			break;
		case "<=":
			writer.setle(get_reg(X64_Register.AL));
			break;

		case "==":
			writer.sete(get_reg(X64_Register.AL));
			break;
		case "!=":
			writer.setne(get_reg(X64_Register.AL));
			break;

		default:
			assert(0, "unhandled op!");
		}

		// writer.movz(get_reg(X64_Register.AL), get_reg(X64_Register.AL));//?
		writer.mov(get_reg(X64_Register.AL), get_val(s.address));
	}

	// a store where the value is
	// a binary operator
	// e.g.
	// t0 = a + b
	void emit_temp(Store s) {
		auto bin = cast(Binary_Op) s.val;

		Reg reg = get_reg(X64_Register.AL);
		
		// TODO
		bool is_floating = (cast(Floating)s.get_type()) !is null;
		if (is_floating) {
			assert(0);
		}

		writer.mov(get_val(bin.a), reg);

		switch (bin.op) {
		case ">":
		case "<":
		case ">=":
		case "<=":
		case "==":
		case "!=":
			return emit_cmp(s);

		case "&&":
			writer.and(get_val(bin.b), reg);
			break;
		case "||":
			writer.or(get_val(bin.b), reg);
			break;

		case "+":
			if (is_floating) {
				writer.addsd(get_val(bin.b), reg);
			} else {
				writer.add(get_val(bin.b), reg);
			}
			break;

		case "-":
			if (is_floating) {
				writer.subsd(get_val(bin.b), reg);
			} else {
				writer.sub(get_val(bin.b), reg);
			}
			break;

		case "/":
			// FIXME
			// a / b
			// dividend / divisor

			if (is_floating) {
				writer.divsd(get_val(bin.b), reg);
			} else {
				// TODO pick CX reg
				writer.mov(get_val(bin.b), get_reg(X64_Register.CX));
				writer.idiv(get_reg(X64_Register.CX));
			}
			break;

		case "*":
			if (is_floating) {
				writer.mulsd(get_val(bin.b), reg);
			} else {
				writer.imul(get_val(bin.b), reg);
			}
			break;

		default:
			logger.fatal("Unhandled instr selection for binary op ", to!string(bin));
			assert(0);
		}

		writer.mov(reg, get_val(s.address));
	}

	void emit_store(Store s) {
		writeln("emitting store for ", s);

		// kind of hacky but ok
		if (auto bin = cast(Binary_Op) s.val) {
			emit_temp(s);
			return;
		}

		Type t = s.get_type();

		auto val = get_val(s.val);
		auto addr = get_val(s.address);

		auto addr_width = s.address.get_type().get_width();

		Reg reg = get_reg(X64_Register.AL);

		bool is_floating = (cast(Floating)s.get_type()) !is null;
		if (is_floating) {
			// TODO
		}

		reg.promote(addr_width);

		// move value into a register
		writer.mov(val, reg);

		// and then move the value from
		// the register into the stack.
		writer.mov(reg, addr);
	}

	void emit_ret(Return ret) {
		if (ret.results !is null) {
			Value v = ret.results[0];
			writer.mov(get_val(v), get_reg(X64_Register.AL));
		}

		// FIXME this wont work all the time...
		// i dont think?!

		// before we return from the function we 
		// have to de-allocate all the stack space
		// we allocated. note that we also set
		// the allocated space here because
		// when we emit the _initial_ subq allocation
		// instruction we don't know how much space
		// has been pushed to the stack!
		writer.emitt_at(curr_ctx.alloc_instr_addr, "subq ${}, %rsp", to!string(curr_ctx.size()));

		writer.add(make_const(curr_ctx.size()), get_reg(X64_Register.RSP));

		writer.pop(get_reg(X64_Register.RBP));
		writer.ret();
	}

	void emit_if(If iff) {
		// emit the condition and 
		// check if it's true
		auto condish = get_val(iff.condition);
		writer.cmp(make_const(1), condish);

		writer.je(mangle(iff.a));
		writer.jmp(mangle(iff.b));
	}

	void emit_jmp(Jump j) {
		writer.jmp(mangle(j.label));
	}

	void emit_mod_access(Module_Access ma) {
		// fixme this is a copy paste of emit_call...

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

			should be stack aligned on 16 byte boundary.
		*/

		import std.algorithm.comparison : min, max;

		if (ma.mod.name !in mod.dependencies) {
			writeln("oh shit no ", ma.mod.name, " for ", mod.mod_name);
		}

		IR_Module other_mod = mod.dependencies[ma.mod.name];

		Call c = cast(Call) ma.right;

		string call_name = ";\n hlt"; // lol FIXME
		if (auto iden = cast(Identifier) c.left) {
			// since this is just a stand alone name
			// its probably going to be a function
			// registered in THIS module, so lets
			// look it up and see if it exists.
			auto func = other_mod.get_function(iden.name);
			assert(func !is null);
			call_name = mangle(func);
		}
		else {
			logger.fatal("unhandled invoke lefthand ! ", to!string(c.left), " for ", to!string(c));
		}

		if ((call_name in other_mod.ctx) is null) {
			logger.verbose("Call context for '", call_name, "' does not exist!");
			foreach (k, v; other_mod.ctx) {
				logger.verbose(k, " => ", to!string(v));
			}
			assert(0);
		}

		// the locals context for the function
		// we're calling.
		Block_Context call_frame_ctx = other_mod.ctx[call_name];

		uint next_float = 0;

		// mov all of the args into the register
		// for the calling convention
		foreach (i, arg; c.args[0..min(c.args.length,SYS_V_CALL_CONV_REG.length)]) {
			if (auto flt = cast(Floating) arg.get_type()) {
				writer.mov(get_val(arg), get_reg(SYS_V_CALL_CONV_REG_FLOATS[next_float++]));
			}
			else if (auto ptr = cast(Pointer) arg.get_type()) {
				writer.lea(get_val(arg), get_reg(SYS_V_CALL_CONV_REG[i]));
			}
			else {
				auto left = get_val(arg);
				auto reg = get_reg(SYS_V_CALL_CONV_REG[i]);
				reg.promote(left.width());
				writer.mov(left, reg);
			}
		}

		if (c.args.length >= SYS_V_CALL_CONV_REG.length) {
			foreach_reverse (i, arg; c.args[SYS_V_CALL_CONV_REG.length..$]) {
				// move the value via. the stack
				auto val = call_frame_ctx.get_addr("__arg_" ~ to!string(i));
				auto addr = new Address(val[0], get_reg(X64_Register.RSP));
				addr.set_width(val[1]);
				writer.mov(get_val(arg), addr);
			}
		}		

		writer.mov(make_const(next_float), get_reg(X64_Register.AL));
		writer.call(call_name);
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

			should be stack aligned on 16 byte boundary.
		*/

		import std.algorithm.comparison : min, max;

		string call_name = ";\n hlt"; // lol FIXME
		if (auto iden = cast(Identifier) c.left) {
			// since this is just a stand alone name
			// its probably going to be a function
			// registered in THIS module, so lets
			// look it up and see if it exists.
			auto func = mod.get_function(iden.name);
			assert(func !is null);
			call_name = mangle(func);
		}
		else {
			logger.fatal("unhandled invoke lefthand ! ", to!string(c.left), " for ", to!string(c));
		}

		if ((call_name in mod.ctx) is null) {
			logger.verbose("Call context for '", call_name, "' does not exist!");
			foreach (k, v; mod.ctx) {
				logger.verbose(k, " => ", to!string(v));
			}
			assert(0);
		}

		// the locals context for the function
		// we're calling.
		Block_Context call_frame_ctx = mod.ctx[call_name];

		uint next_float = 0;

		// mov all of the args into the register
		// for the calling convention
		foreach (i, arg; c.args[0..min(c.args.length,SYS_V_CALL_CONV_REG.length)]) {
			if (auto flt = cast(Floating) arg.get_type()) {
				writer.mov(get_val(arg), get_reg(SYS_V_CALL_CONV_REG_FLOATS[next_float++]));
			}
			else if (auto ptr = cast(Pointer) arg.get_type()) {
				writer.lea(get_val(arg), get_reg(SYS_V_CALL_CONV_REG[i]));
			}
			else {
				writer.mov(get_val(arg), get_reg(SYS_V_CALL_CONV_REG[i]));
			}
		}

		if (c.args.length >= SYS_V_CALL_CONV_REG.length) {
			foreach_reverse (i, arg; c.args[SYS_V_CALL_CONV_REG.length..$]) {
				// move the value via. the stack
				auto val = call_frame_ctx.get_addr("__arg_" ~ to!string(i));
				auto addr = new Address(val[0], get_reg(X64_Register.RSP));
				addr.set_width(val[1]);
				writer.mov(get_val(arg), addr);
			}
		}		

		writer.mov(make_const(next_float), get_reg(X64_Register.AL));
		writer.call(call_name);
	}

	void emit_instr(Instruction i) {
		if (auto alloc = cast(Alloc)i) {
			auto addr = curr_ctx.push_local(alloc.name, alloc.get_type());
			logger.verbose("Emitting local ", to!string(alloc), " at addr ", to!string(addr), "(%rsp)");
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
		else if (auto ma = cast(Module_Access)i) {
			emit_mod_access(ma);
		}
		else {
			logger.fatal("x64_gen: unhandled instruction ", to!string(typeid(cast(Basic_Instruction)i)), ":\n\t", to!string(i));
		}
	}

	void emit_bb(Basic_Block bb) {
		writer.emit("{}:", mangle(bb));
		foreach (instr; bb.instructions) {
			emit_instr(instr);
		}
	}

	void emit_mod(IR_Module mod) {
		this.mod = mod;

		writer.set_segment(Segment.Data);
		foreach (k, v; mod.constants) {
			emit_data_const(k, v);
		}

		writer.set_segment(Segment.Text);
		foreach (ref name, func; mod.c_funcs) {
			setup_func_proto(func);
		}
		foreach (ref name, func; mod.functions) {
			setup_func_proto(func);
		}

		foreach (ref name, func; mod.functions) {
			emit_func(func);
		}

		// emit the main function bootstrap function
		// if this module has a main func

		// hack mangle for the entry label
		string entry_label = "main";
		version (OSX) {
			entry_label = "_main";
		}

		// if our module has a main function
		// we emitt the main asm procedure
		// which the program is entered by.
		// there is an assumption that 
		// _only one module in the program
		// has a main function!_
		auto main_func = mod.get_function("main");
		if (main_func !is null) {
			writer.emit(".global {}", entry_label);
			writer.emit("{}:", entry_label);

			writer.push(get_reg(X64_Register.RBP));
			writer.mov(get_reg(X64_Register.RSP), get_reg(X64_Register.RBP));

			writer.call(mangle(main_func));

			writer.pop(get_reg(X64_Register.RBP));
			writer.ret();
		}			
	}

	void push_block_ctx(Function func) {
		auto new_ctx = new Block_Context(func);
		logger.verbose("Pushing local context for func '", func.name, "'");
		mod.ctx[mangle(func)] = new_ctx;
		curr_ctx = new_ctx;
	}

	void setup_func_proto(Function func) {
		push_block_ctx(func);

		// push all of the param allocs
		// into the current block context
		// we mangle the names to __arg_N
		// where N is the index of the argument.
		if (func.params.length >= SYS_V_CALL_CONV_REG.length) {
			foreach_reverse (i, arg; func.params[SYS_V_CALL_CONV_REG.length..$]) {
				curr_ctx.push_local("__arg_" ~ to!string(i), arg.get_type().get_width());
			}
		}
	}

	void emit_func(Function func) {
		curr_func = func;
		// hm		
		if (func.has_attribute("c_func")) {
			return;
		}

		curr_ctx = mod.ctx[mangle(func)];

		// temp hack
		if (isUpper(func.name[0])) {
			writer.emit(".global {}", mangle(func));
		}

		writer.emit("{}:", mangle(func));

		writer.push(get_reg(X64_Register.RBP));
		writer.mov(get_reg(X64_Register.RSP), get_reg(X64_Register.RBP));

		// PLACEHOLDER value here, we subtract 0 from the
		// RSP but we later on MODIFY THIS to however much
		// bytes we allocated (aligned to a 16 byte boundary).
		// this is why we store the address which this instruction
		// was written to
		curr_ctx.alloc_instr_addr = writer.emitt("subq $0, %rsp");

		// HACK
		// basically we spill all of the registers onto
		// the stack since we're abiding by the call
		// conventions of passing to the registers
		foreach (ref idx, param; func.params) {
			const auto twine = "__arg_" ~ to!string(idx);

			auto val = curr_ctx.get_addr(twine);
			if (val[0] == -1) {
				val = curr_ctx.push_local(twine, param.get_type());
			}

			auto addr = new Address(val[0], get_reg(X64_Register.RSP));
			addr.set_width(val[1]);
			writer.mov(get_reg(SYS_V_CALL_CONV_REG[idx]), addr);
		}

		foreach (ref bb; func.blocks) {
			emit_bb(bb);
		}

		// if there is no return instr
		// slap one on the end.
		if (!(cast(Return) func.last_instr())) {
			emit_ret(new Return(new Void()));
		}
	}
}

static int align_to(int n, int m) {
    int rem = n % m;
    return (rem == 0) ? n : n - rem + m;
}