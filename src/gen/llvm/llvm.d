module gen.llvm.ir;

extern(C) {
	alias LLVMString = immutable(char)*;

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

	enum LLVMVerifierFailureAction {
		LLVMAbortProcessAction, 	
		LLVMPrintMessageAction, 	
		LLVMReturnStatusAction,
	};

	enum LLVMIntPredicate { 
		LLVMIntEQ = 32, LLVMIntNE, LLVMIntUGT, LLVMIntUGE, 
		LLVMIntULT, LLVMIntULE, LLVMIntSGT, LLVMIntSGE, 
		LLVMIntSLT, LLVMIntSLE 
	}

	// modules
	struct LLVMOpaqueModule{};
	alias LLVMModuleRef = LLVMOpaqueModule*;

	LLVMModuleRef LLVMModuleCreateWithName(LLVMString name);

	LLVMValueRef LLVMAddFunction(LLVMModuleRef, LLVMString, LLVMTypeRef);
	LLVMValueRef LLVMAddGlobal(LLVMModuleRef, LLVMTypeRef, LLVMString);

	void LLVMVerifyModule(LLVMModuleRef, LLVMVerifierFailureAction, LLVMString* out_msg);

	void LLVMDumpModule(LLVMModuleRef);

	// values
	struct LLVMOpaqueValue{};
	alias LLVMValueRef = LLVMOpaqueValue*;

	LLVMValueRef LLVMConstInt(LLVMTypeRef, ulong val, bool);
	LLVMValueRef LLVMConstString(LLVMString, ulong, bool);

	enum LLVMTypeKind { 
		LLVMVoidTypeKind, LLVMHalfTypeKind, LLVMFloatTypeKind, LLVMDoubleTypeKind, 
		LLVMX86_FP80TypeKind, LLVMFP128TypeKind, LLVMPPC_FP128TypeKind, LLVMLabelTypeKind, 
		LLVMIntegerTypeKind, LLVMFunctionTypeKind, LLVMStructTypeKind, LLVMArrayTypeKind, 
		LLVMPointerTypeKind, LLVMVectorTypeKind, LLVMMetadataTypeKind, LLVMX86_MMXTypeKind, 
		LLVMTokenTypeKind
	};

	LLVMTypeKind LLVMGetTypeKind(LLVMTypeRef);

	// types
	struct LLVMOpaqueType{};
	alias LLVMTypeRef = LLVMOpaqueType*;

	// types
	LLVMTypeRef LLVMVoidType();
	LLVMTypeRef LLVMInt8Type();
	LLVMTypeRef LLVMInt16Type();
	LLVMTypeRef LLVMInt32Type();
	LLVMTypeRef LLVMInt64Type();

	LLVMTypeRef LLVMStructType(LLVMTypeRef*, ulong, bool);
	LLVMTypeRef LLVMIntType(uint);

	LLVMTypeRef LLVMArrayType(LLVMTypeRef, ulong);
	LLVMTypeRef LLVMFunctionType(LLVMTypeRef, LLVMTypeRef*, ulong, bool);
	LLVMTypeRef LLVMPointerType(LLVMTypeRef, int);

	LLVMTypeRef LLVMTypeOf(LLVMValueRef);
	LLVMTypeRef LLVMGetElementType(LLVMTypeRef);

	void LLVMSetLinkage(LLVMValueRef, LLVMLinkage);
	void LLVMSetInitializer(LLVMValueRef, LLVMValueRef);
	void LLVMSetGlobalConstant(LLVMValueRef, bool);

	// basic blocks
	struct LLVMOpaqueBasicBlock{};
	alias LLVMBasicBlockRef = LLVMOpaqueBasicBlock*;

	LLVMBasicBlockRef LLVMAppendBasicBlock(LLVMValueRef, LLVMString);
	LLVMBasicBlockRef LLVMInsertBasicBlock(LLVMBasicBlockRef, LLVMString);
	LLVMBasicBlockRef LLVMGetPreviousBasicBlock(LLVMBasicBlockRef);

	LLVMValueRef LLVMGetNamedFunction(LLVMModuleRef, LLVMString);
	LLVMValueRef LLVMGetParam(LLVMValueRef, uint);
	uint LLVMCountParams(LLVMValueRef);

	// builder
	struct LLVMOpaqueBuilder{};
	alias LLVMBuilderRef = LLVMOpaqueBuilder*;

	LLVMBuilderRef LLVMCreateBuilder();
	void LLVMPositionBuilderAtEnd(LLVMBuilderRef, LLVMBasicBlockRef);
	LLVMValueRef LLVMBuildAlloca(LLVMBuilderRef, LLVMTypeRef, LLVMString);
	LLVMValueRef LLVMBuildStore(LLVMBuilderRef, LLVMValueRef, LLVMValueRef);
	LLVMValueRef LLVMBuildCall(LLVMBuilderRef, LLVMValueRef, LLVMValueRef*, ulong, LLVMString);
	LLVMValueRef LLVMBuildBr(LLVMBuilderRef, LLVMBasicBlockRef);

	LLVMValueRef LLVMBuildZExt(LLVMBuilderRef, LLVMValueRef, LLVMTypeRef, LLVMString);

	LLVMValueRef LLVMBuildShl(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, LLVMString);
	
	LLVMValueRef LLVMBuildLShr(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, LLVMString);

	LLVMValueRef LLVMBuildXor(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, LLVMString);
	LLVMValueRef LLVMBuildOr(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, LLVMString);
	LLVMValueRef LLVMBuildAnd(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, LLVMString);

	LLVMValueRef LLVMBuildTrunc(LLVMBuilderRef, LLVMValueRef, LLVMTypeRef, LLVMString);

	LLVMValueRef LLVMBuildCondBr(LLVMBuilderRef, LLVMValueRef, LLVMBasicBlockRef, LLVMBasicBlockRef);

	LLVMValueRef LLVMBuildRetVoid(LLVMBuilderRef);
	LLVMValueRef LLVMBuildRet(LLVMBuilderRef, LLVMValueRef);

	LLVMValueRef LLVMBuildSub(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, LLVMString);
	LLVMValueRef LLVMBuildAdd(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, LLVMString);
	LLVMValueRef LLVMBuildMul(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, LLVMString);

	LLVMValueRef LLVMBuildURem(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, LLVMString);
	LLVMValueRef LLVMBuildSRem(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, LLVMString);
	
	LLVMValueRef LLVMBuildUDiv(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, LLVMString);
	LLVMValueRef LLVMBuildSDiv(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, LLVMString);

	// unary
	LLVMValueRef LLVMBuildNeg(LLVMBuilderRef, LLVMValueRef, LLVMString);

	LLVMValueRef LLVMBuildLoad(LLVMBuilderRef, LLVMValueRef, LLVMString);

	// comparison
	LLVMValueRef LLVMBuildICmp(LLVMBuilderRef, LLVMIntPredicate, LLVMValueRef, LLVMValueRef, LLVMString);

	LLVMValueRef LLVMBuildGlobalStringPtr(LLVMBuilderRef, LLVMString, LLVMString);

	// get element ptr stuff
	LLVMValueRef LLVMBuildInBoundsGEP(LLVMBuilderRef, LLVMValueRef, LLVMValueRef*, ulong, LLVMString);

	LLVMValueRef LLVMBuildStructGEP(LLVMBuilderRef, LLVMValueRef, ulong, LLVMString);
	LLVMValueRef LLVMBuildGEP(LLVMBuilderRef, LLVMValueRef, LLVMValueRef*, ulong, LLVMString);

	//
	// writing to asm obj etc.
	//

	enum LLVMCodeGenFileType {
		LLVMAssemblyFile,
		LLVMObjectFile,	
	};

	enum LLVMCodeGenOptLevel {
		LLVMCodeGenLevelNone,
		LLVMCodeGenLevelLess,
		LLVMCodeGenLevelDefault,
		LLVMCodeGenLevelAggressive,
	};

	enum LLVMCodeModel {
		LLVMCodeModelDefault,
		LLVMCodeModelJITDefault,
		LLVMCodeModelSmall,
		LLVMCodeModelKernel,
		LLVMCodeModelMedium,
		LLVMCodeModelLarge,
	};

	enum LLVMRelocMode {
		LLVMRelocDefault,
		LLVMRelocStatic,
		LLVMRelocPIC,
		LLVMRelocDynamicNoPic,
	};

	void LLVMDisposeMessage(LLVMString);

	// memory buffer
	struct LLVMOpaqueMemoryBuffer{};
	alias LLVMMemoryBufferRef = LLVMOpaqueMemoryBuffer*;

	struct LLVMOpaqueTargetMachine{};
	alias LLVMTargetMachineRef = LLVMOpaqueTargetMachine*;

	void LLVMTargetMachineEmitToMemoryBuffer(LLVMTargetMachineRef, LLVMModuleRef, LLVMCodeGenFileType, LLVMString*, LLVMMemoryBufferRef*);

	struct LLVMTarget{};
	alias LLVMTargetRef = LLVMTarget*;

	/*
	LLVM_TARGET(AArch64)
	LLVM_TARGET(AMDGPU)
	LLVM_TARGET(ARM)
	LLVM_TARGET(BPF)
	LLVM_TARGET(Hexagon)
	LLVM_TARGET(Lanai)
	LLVM_TARGET(Mips)
	LLVM_TARGET(MSP430)
	LLVM_TARGET(NVPTX)
	LLVM_TARGET(PowerPC)
	LLVM_TARGET(Sparc)
	LLVM_TARGET(SystemZ)
	LLVM_TARGET(X86)
	LLVM_TARGET(XCore)

	*LLVMInitializeAllTargets()

	TODO the initialize all * are compiled static inline
	so they dont end up in the object files
	which gives us an undefined reference.
	do some d magic stuff to generate all of these
	*/

	int LLVMInitializeX86TargetInfo();
	int LLVMInitializeX86Target();
	int LLVMInitializeX86TargetMC();
	int LLVMInitializeX86AsmPrinter();
	int LLVMInitializeX86AsmParser();

	immutable(char)* LLVMGetBufferStart(LLVMMemoryBufferRef buff);
	int LLVMGetBufferSize(LLVMMemoryBufferRef buff);

	LLVMString LLVMGetDefaultTargetTriple();
	int LLVMGetTargetFromTriple(LLVMString, LLVMTargetRef*, LLVMString*);
	LLVMTargetMachineRef LLVMCreateTargetMachine(LLVMTargetRef, LLVMString, LLVMString, LLVMString, LLVMCodeGenOptLevel, LLVMRelocMode, LLVMCodeModel);
}