module gen.llvm.type_conv;

import std.stdio;
import std.conv : to;

import gen.llvm.ir;
import sema.type;

LLVMTypeRef to_llvm_int(Integer i) {
	final switch (i.get_width) {
	case 1:
		return LLVMInt8Type();
	case 2:
		return LLVMInt16Type();
	case 4:
		return LLVMInt32Type();
	case 8:
		return LLVMInt64Type();
	}
}

LLVMTypeRef to_llvm_type(Structure s) {
	LLVMTypeRef[] conv_types;
	foreach (t; s.types) {
		conv_types ~= to_llvm_type(t);
	}

	// TODO packed attribute.
	return LLVMStructType(cast(LLVMTypeRef*)conv_types, conv_types.length, false);
}

LLVMTypeRef to_llvm_type(Array a) {
	return LLVMArrayType(to_llvm_type(a.base), a.length);
}

LLVMTypeRef to_llvm_type(Type t) {
	if (t is null) {
		assert(0);
	}

	if (cast(Void) t) {
		return LLVMVoidType();
	}
	else if (auto integer = cast(Integer) t) {
		return to_llvm_int(integer);
	}
	else if (auto ptr = cast(Pointer) t) {
		auto base = to_llvm_type(ptr.base);
		return LLVMPointerType(base, 0);
	}
	else if (auto cstr = cast(CString) t) {
		// questionable...
		return to_llvm_type(cstr.types[0]);
	}
	else if (auto structure = cast(Structure) t) {
		return to_llvm_type(structure);
	}
	else if (auto array = cast(Array) t) {
		return to_llvm_type(array);
	}

	writeln("unhandled type ! ", t, typeid(t));
	assert(0);
}