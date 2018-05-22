module gen.llvm.writer;

import std.string;

import kir.ir_mod;
import kir.instr;

import gen.llvm.driver : LLVM_Gen_Output;
import gen.llvm.ir;
import gen.llvm.type_conv;

class LLVM_Writer : LLVM_Gen_Output {
	IR_Module mod;

	LLVMModuleRef llvm_mod;
	LLVMBuilderRef builder;

	this(IR_Module mod) {
		this.mod = mod;

		// TODO make the name the path or something
		// or mangle the mod name idk.
		this.llvm_mod = LLVMModuleCreateWithName(mod.mod_name.toStringz);

		this.builder = LLVMCreateBuilder();
	}

	void write_func(Function f) {
		LLVMTypeRef[] params;
		foreach (alloc; f.params) {
			params ~= to_llvm_type(alloc.get_type());
		}

		auto ret_type = to_llvm_type(f.get_type());
		auto func_type = LLVMFunctionType(ret_type, params, params.length, 0);
		LLVMValueRef func = LLVMAddFunction(llvm_mod, f.name.toStringz, func_type);
		
		// TODO
		LLVMSetLinkage(func, LLVMLinkage.LLVMExternalLinkage);

		LLVMDumpModule(llvm_mod);
	}

	LLVM_Gen_Output gen() {
		LLVM_Gen_Output generated_llvm_mod;
		foreach (func; mod.functions) {
			write_func(func);
		}
		return generated_llvm_mod;
	}
}