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

	// type val
	struct LLVMOpaqueType{};
	alias LLVMTypeRef = LLVMOpaqueType*;

	struct LLVMOpaqueValue{};
	alias LLVMValueRef = LLVMOpaqueValue*;
	
	// types
	LLVMTypeRef LLVMVoidType();
	LLVMTypeRef LLVMInt32Type();
	LLVMTypeRef LLVMFunctionType(LLVMTypeRef, LLVMTypeRef[], ulong, int);

	void LLVMSetLinkage(LLVMValueRef, LLVMLinkage);

	// b
	struct LLVMBasicBlockRef{};

	// builder
	struct LLVMOpaqueBuilder{};
	alias LLVMBuilderRef = LLVMOpaqueBuilder*;

	LLVMBuilderRef LLVMCreateBuilder();
}