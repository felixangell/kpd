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
}

class LLVM_Writer : LLVM_Gen_Output {
	IR_Module mod;

	LLVMModuleRef llvm_mod;
	LLVMBuilderRef builder;

	LLVMValueRef curr_func_addr;
	Function_Context[LLVMValueRef] ctx;

	// TODO put this into a func context
	// this technically would be ok since parameters
	// names cannot collide with variable names.
	LLVMValueRef[string] allocs;

	LLVMValueRef[string] function_protos;	
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

	void write_alloc(Alloc a) {
		auto alloc_name = a.name;
		auto var = LLVMBuildAlloca(builder, to_llvm_type(a.get_type()), alloc_name.toStringz);
		allocs[alloc_name] = var;
	}

	LLVMValueRef emit_const(Constant c) {
		auto type = c.get_type();
		auto conv_type = to_llvm_type(type);

		if (auto integer = cast(Integer) type) {
			return LLVMConstInt(conv_type, to!ulong(c.value), false);
		}
		else if (auto cstr = cast(CString) type) {
			return LLVMConstString(c.value.toStringz, c.value.length, false);
		}

		writeln("unhandled constant type ", c, " of type ", c.get_type());
		assert(0);
	}

	LLVMValueRef emit_cref(Constant_Reference cref) {
		return constants[cref.name];
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
				// FIXME
				return function_protos[iden.name];
			}			
			return allocs[iden.name];
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

	void write_invoke(Call i) {
		LLVMValueRef[] args;
		foreach (arg; i.args) {
			args ~= emit_val(arg);
		}

		auto func_addr = emit_val(i.left);
		auto ir_func = functions[func_addr];
		auto name = mangle(ir_func);

		LLVMBuildCall(builder, func_addr, cast(LLVMValueRef*)args, args.length, name.toStringz);
	}

	void write_ret(Return r) {
		if (cast(Void)r.get_type()) {
			LLVMBuildRetVoid(builder);
			return;
		}
	}

	void write_instr(Instruction instr) {
		if (auto alloc = cast(Alloc) instr) {
			write_alloc(alloc);
		}
		else if (auto store = cast(Store) instr) {
			write_store(store);
		}
		else if (auto invoke = cast(Call) instr) {
			write_invoke(invoke);
		}
		else if (auto ret = cast(Return) instr) {
			write_ret(ret);
		}
		else {
			writeln("unhandled instruction!!! ", to!string(instr));
			assert(0);
		}
	}

	void write_bb(LLVMValueRef func, Basic_Block b) {
		auto bb = LLVMAppendBasicBlock(func, mangle(b).toStringz);
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

		const auto mangled_fname = mangle(f);

		auto ret_type = to_llvm_type(f.get_type());
		auto func_type = LLVMFunctionType(ret_type, cast(LLVMTypeRef*)params, params.length, 0);
		LLVMValueRef func = LLVMAddFunction(llvm_mod, mangled_fname.toStringz, func_type);
		
		functions[func] = f;
		function_protos[f.name] = func;
	}

	void write_func(Function f) {
		auto func = function_protos[f.name];
		
		// TODO
		curr_func_addr = func;
		
		// TODO
		LLVMSetLinkage(func, LLVMLinkage.LLVMExternalLinkage);

		foreach (bb; f.blocks) {
			write_bb(func, bb);
		}

		LLVMDumpModule(llvm_mod);
	}

	LLVM_Gen_Output gen() {
		LLVM_Gen_Output generated_llvm_mod;
		
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

		return generated_llvm_mod;
	}
}