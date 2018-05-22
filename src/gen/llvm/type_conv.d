module gen.llvm.type_conv;

import std.stdio;
import std.conv : to;

import gen.llvm.ir;
import sema.type;

LLVMTypeRef to_llvm_type(Type t) {
	if (t is null) {
		assert(0);
	}

	if (cast(Void) t) {
		return LLVMVoidType();
	}

	writeln("unhandled type ! ", t, typeid(t));
	assert(0);
}