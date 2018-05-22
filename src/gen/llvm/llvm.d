module gen.llvm.ir;

extern(C) {
	private alias LLVMString = immutable(char)*;

	enum LLVMLinkage {
		LLVMExternalLinkage,
		LLVMAvailableExternallyLinkage,
		LLVMLinkOnceAnyLinkage,
		LLVMLinkOnceODRLinkage,
		LLVMLinkOnceODRAutoHideLinkage,
		LLVMWeakAnyLinkage,
		LLVMWeakODRLinkage,
		LLVMAppendingLinkage,
		LLVMInternalLinkage,
		LLVMPrivateLinkage,
		LLVMDLLImportLinkage,
		LLVMDLLExportLinkage,
		LLVMExternalWeakLinkage,
		LLVMGhostLinkage,
		LLVMCommonLinkage,
		LLVMLinkerPrivateLinkage,
		LLVMLinkerPrivateWeakLinkage
	};

	struct LLVMVerifierFailureAction{};

	// modules
	struct LLVMOpaqueModule{};
	alias LLVMModuleRef = LLVMOpaqueModule*;

	LLVMModuleRef LLVMModuleCreateWithName(LLVMString name);

	LLVMValueRef LLVMAddFunction(LLVMModuleRef, LLVMString, LLVMTypeRef);
	void LLVMVerifyModule(LLVMModuleRef, LLVMVerifierFailureAction, LLVMString* out_msg);

	void LLVMDumpModule(LLVMModuleRef);

	// values
	struct LLVMOpaqueValue{};
	alias LLVMValueRef = LLVMOpaqueValue*;

	LLVMValueRef LLVMConstInt(LLVMTypeRef, ulong val, bool);
	LLVMValueRef LLVMConstString(LLVMString, ulong, bool);

	// types
	struct LLVMOpaqueType{};
	alias LLVMTypeRef = LLVMOpaqueType*;

	// types
	LLVMTypeRef LLVMVoidType();
	LLVMTypeRef LLVMInt8Type();
	LLVMTypeRef LLVMInt16Type();
	LLVMTypeRef LLVMInt32Type();
	LLVMTypeRef LLVMInt64Type();
	LLVMTypeRef LLVMFunctionType(LLVMTypeRef, LLVMTypeRef*, ulong, int);
	LLVMTypeRef LLVMPointerType(LLVMTypeRef, int);

	void LLVMSetLinkage(LLVMValueRef, LLVMLinkage);

	// basic blocks
	struct LLVMOpaqueBasicBlock{};
	alias LLVMBasicBlockRef = LLVMOpaqueBasicBlock*;

	LLVMBasicBlockRef LLVMAppendBasicBlock(LLVMValueRef, LLVMString);

	// builder
	struct LLVMOpaqueBuilder{};
	alias LLVMBuilderRef = LLVMOpaqueBuilder*;

	LLVMBuilderRef LLVMCreateBuilder();
	void LLVMPositionBuilderAtEnd(LLVMBuilderRef, LLVMBasicBlockRef);
	LLVMValueRef LLVMBuildAlloca(LLVMBuilderRef, LLVMTypeRef, LLVMString);
	LLVMValueRef LLVMBuildStore(LLVMBuilderRef, LLVMValueRef, LLVMValueRef);
	LLVMValueRef LLVMBuildCall(LLVMBuilderRef, LLVMValueRef, LLVMValueRef*, ulong, LLVMString);
	LLVMValueRef LLVMBuildRetVoid(LLVMBuilderRef);
}