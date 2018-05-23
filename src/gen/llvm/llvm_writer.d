module gen.llvm.writer;

import std.stdio;
import std.string;
import std.conv : to;

import kir.ir_mod;
import kir.instr;

import sema.type;

import gen.mangler;
import gen.llvm.driver : LLVM_Gen_Output;
import gen.llvm.ir;
import gen.llvm.type_conv;

class Function_Context {
	Function_Context outer;
	LLVMValueRef addr;

	LLVMBasicBlockRef[string] bb_entries;

	LLVMBasicBlockRef push_bb(string label) {
		auto bb = LLVMAppendBasicBlock(addr, label.toStringz);
		assert(label !in bb_entries);
		register_bb(label, bb);
		return bb;
	}

	LLVMBasicBlockRef register_bb(string label, LLVMBasicBlockRef bb) {
		writeln("registering entry ", label);
		bb_entries[label] = bb;
		return bb;
	}

	LLVMBasicBlockRef get_bb(string label) {
		writeln("looking up ", label);
		return bb_entries[label];
	}

	this(Function_Context outer, LLVMValueRef addr) {
		this.outer = outer;
		this.addr = addr;
	}
}

class LLVM_Writer {
	IR_Module mod;

	LLVMModuleRef llvm_mod;
	LLVMBuilderRef builder;

	Function_Context curr_func;

	void push_func(LLVMValueRef addr) {
		auto old_func = curr_func;
		curr_func = new Function_Context(old_func, addr);
	}

	Function_Context pop_func() {
		auto old = curr_func;
		curr_func = curr_func.outer;
		return old;
	}

	// TODO put this into a func context
	// this technically would be ok since parameters
	// names cannot collide with variable names.
	LLVMValueRef[string] allocs;

	LLVMTypeRef[string] function_protos;
	LLVMValueRef[string] function_addr;
	Function[LLVMValueRef] functions;

	LLVMValueRef[string] constants;

	this(IR_Module mod) {
		this.mod = mod;

		// TODO make the name the path or something
		// or mangle the mod name idk.
		this.llvm_mod = LLVMModuleCreateWithName(mod.mod_name.toStringz);

		this.builder = LLVMCreateBuilder();
	}

	LLVMValueRef write_alloc(Alloc a) {
		auto alloc_name = a.name;
		auto var = LLVMBuildAlloca(builder, to_llvm_type(a.get_type()), alloc_name.toStringz);
		allocs[alloc_name] = var;
		return var;
	}

	LLVMValueRef emit_const(Constant c) {
		auto type = c.get_type();
		auto conv_type = to_llvm_type(type);

		if (auto integer = cast(Integer) type) {
			return LLVMConstInt(conv_type, to!ulong(c.value), false);
		}
		else if (auto cstr = cast(CString) type) {
			auto strlen = c.value.length;
			auto str = LLVMAddGlobal(llvm_mod, LLVMPointerType(LLVMInt8Type(), 0), "");
			LLVMSetLinkage(str, LLVMLinkage.LLVMInternalLinkage);
			LLVMSetGlobalConstant(str, true);

			auto str_const = LLVMConstString(c.value[1..$-1].toStringz, strlen, true);
			LLVMSetInitializer(str, str_const);

			auto indices = [
				LLVMConstInt(LLVMInt64Type(), 0, false),
			];
			return LLVMBuildGEP(builder, str_const, cast(LLVMValueRef*)indices, indices.length, "");
		}

		writeln("unhandled constant type ", c, " of type ", c.get_type());
		assert(0);
	}

	LLVMValueRef emit_cref(Constant_Reference cref) {
		return constants[cref.name];
	}

	LLVMValueRef emit_cmp(Binary_Op bin) {
		auto lhs = emit_val(bin.a);
		auto rhs = emit_val(bin.b);
		return LLVMBuildICmp(builder, LLVMIntPredicate.LLVMIntEQ, lhs, rhs, "");
	}

	LLVMValueRef emit_and(Binary_Op bin) {
		auto lhs = emit_val(bin.a);
		auto rhs = emit_val(bin.b);
		return LLVMBuildAnd(builder, lhs, rhs, "");
	}

	LLVMValueRef emit_or(Binary_Op bin) {
		auto lhs = emit_val(bin.a);
		auto rhs = emit_val(bin.b);
		return LLVMBuildOr(builder, lhs, rhs, "");
	}

	LLVMValueRef emit_binary_op(Binary_Op bin) {
		switch (bin.op) {
		case "-":
			return LLVMBuildSub(builder, emit_val(bin.a), emit_val(bin.b), "");
		case "+":
			return LLVMBuildAdd(builder, emit_val(bin.a), emit_val(bin.b), "");
		case "==":
			return emit_cmp(bin);
		case "&&":
			return emit_and(bin);
		case "||":
			return emit_or(bin);
		default:
			assert(0, "emit_binary_op: operator unhandled '" ~ to!string(bin.op) ~ "'");
		}
	}

	LLVMValueRef emit_val(Value v) {
		if (auto c = cast(Constant) v) {
			return emit_const(c);
		}
		else if (auto cref = cast(Constant_Reference) v) {
			return emit_cref(cref);
		}
		else if (auto iden = cast(Identifier) v) {
			if (iden.name !in allocs) {
				assert(iden.name in function_addr, "no such iden '" ~ to!string(iden.name) ~ "'");
				return function_addr[iden.name];
			}
			LLVMValueRef a = allocs[iden.name];
			return LLVMBuildLoad(builder, a, "");
		}
		else if (auto binary = cast(Binary_Op) v) {
			return emit_binary_op(binary);
		}
		else if (auto invoke = cast(Call) v) {
			return emit_invoke(invoke);
		}

		writeln("unhandled value!", v);
		assert(0);
	}

	void write_store(Alloc a, Store s) {
		auto addr = allocs[a.name];
		LLVMBuildStore(builder, emit_val(s.val), addr);
	}

	void write_store(Store s) {
		if (auto alloc = cast(Alloc) s.address) {
			write_store(alloc, s);
		}
		else {
			writeln("unhandled write store address ! ", s);
		}
	}

	LLVMValueRef emit_invoke(Call i) {
		LLVMValueRef[] args;
		foreach (arg; i.args) {
			args ~= emit_val(arg);
		}

		auto func_addr = emit_val(i.left);
		auto ir_func = functions[func_addr];
		auto name = mangle(ir_func);

		return LLVMBuildCall(builder, func_addr, cast(LLVMValueRef*)args, args.length, name.toStringz);
	}

	void write_ret(Return r) {
		if (cast(Void)r.get_type()) {
			LLVMBuildRetVoid(builder);
			return;
		}

		// TODO build multiple values?
		LLVMBuildRet(builder, emit_val(r.results[0]));
	}

	void write_jmp(Jump j) {
		auto bb = curr_func.get_bb(mangle(j.label));
		LLVMBuildBr(builder, bb);
	}

	void write_iff(If iff) {
		auto if_true = curr_func.get_bb(mangle(iff.a));
		auto end = curr_func.get_bb(mangle(iff.b));

		auto prev = LLVMGetPreviousBasicBlock(if_true);

		// register before the if_true block.
		auto entry = LLVMInsertBasicBlock(if_true, "if_condition");
		curr_func.register_bb("if_condition", entry);

		// add a jump from the prev block to our if_condition
		LLVMPositionBuilderAtEnd(builder, prev);
		LLVMBuildBr(builder, entry);

		// entry block
		LLVMPositionBuilderAtEnd(builder, entry);
		auto do_br = emit_val(iff.condition);
		auto do_br_trunc = LLVMBuildTrunc(builder, do_br, LLVMIntType(1), "");
		LLVMBuildCondBr(builder, do_br_trunc, if_true, end);
	}

	void write_instr(Instruction instr) {
		if (auto alloc = cast(Alloc) instr) {
			write_alloc(alloc);
		}
		else if (auto store = cast(Store) instr) {
			write_store(store);
		}
		else if (auto invoke = cast(Call) instr) {
			emit_invoke(invoke);
		}
		else if (auto ret = cast(Return) instr) {
			write_ret(ret);
		}
		else if (auto iff = cast(If) instr) {
			write_iff(iff);
		}
		else if (auto j = cast(Jump) instr) {
			write_jmp(j);
		}
		else {
			writeln("unhandled instruction!!! ", to!string(instr));
			assert(0);
		}
	}

	bool is_branching_instr(Instruction i) {
		return cast(Jump)i || cast(Return) i || cast(If) i;
	}

	void write_bb(LLVMBasicBlockRef bb, LLVMValueRef func, Basic_Block b) {
		LLVMPositionBuilderAtEnd(builder, bb);
		foreach (instr; b.instructions) {
			write_instr(instr);
		}
	}

	void write_func_proto(Function f) {
		LLVMTypeRef[] params;
		foreach (alloc; f.params) {
			params ~= to_llvm_type(alloc.get_type());
		}

		const auto mangled_fname = f.has_attribute("no_mangle") || f.has_attribute("c_func") ? f.name : mangle(f);

		bool variadic = f.has_attribute("variadic");

		auto ret_type = to_llvm_type(f.get_type());
		auto func_type = LLVMFunctionType(ret_type, cast(LLVMTypeRef*)params, params.length, variadic);

		LLVMValueRef func = LLVMAddFunction(llvm_mod, mangled_fname.toStringz, func_type);
		function_addr[f.name] = func;
		functions[func] = f;
		function_protos[f.name] = func_type;
	}

	void write_func(Function f) {
		auto func_type = function_protos[f.name];

		auto fname = f.has_attribute("no_mangle") ? f.name : mangle(f);

		LLVMValueRef func = LLVMGetNamedFunction(llvm_mod, fname.toStringz);
		function_addr[f.name] = func;
		functions[func] = f;

		push_func(func);
		
		// TODO
		LLVMSetLinkage(func, LLVMLinkage.LLVMExternalLinkage);

		// create llvm bbs for all
		// the blocks in the func for now.
		foreach (bb; f.blocks) {
			auto llvmbb = curr_func.push_bb(mangle(bb));
		}

		// generate the first basic block
		// we do this manually so we can set the
		// allocas to be the values passed from the params
		auto fs = f.blocks[0];
		auto llvm_fs_bb = curr_func.get_bb(mangle(fs));
		{
			LLVMPositionBuilderAtEnd(builder, llvm_fs_bb);

			auto param_count = LLVMCountParams(curr_func.addr);
			for (auto i = 0; i < param_count; i++) {
				auto alloca = write_alloc(f.params[i]);
				allocs[f.params[i].name] = alloca;

				LLVMBuildStore(builder, LLVMGetParam(curr_func.addr, i), alloca);
			}
		}

		write_bb(llvm_fs_bb, func, fs);

		// then we populate.
		foreach (bb; f.blocks[1..$]) {
			auto llvmbb = curr_func.get_bb(mangle(bb));
			write_bb(llvmbb, func, bb);
		}

		LLVMDumpModule(llvm_mod);

		pop_func();
	}

	LLVM_Gen_Output gen(LLVMTargetMachineRef target_machine) {
		foreach (key, constant; mod.constants) {
			constants[key] = emit_val(constant);
		}

		// function protos first
		{
			// c funcs are just protos.
			foreach (func; mod.c_funcs) {
				write_func_proto(func);
			}
			foreach (func; mod.functions) {
				write_func_proto(func);
			}
		}

		// then functions + bodies
		foreach (func; mod.functions) {
			write_func(func);
		}

		return new LLVM_Gen_Output(llvm_mod, target_machine);
	}
}