module gen.x64.instr;

enum X64_Register : ubyte {
	AL,
	BL,
	CL,
	DL,
	SIL,
	DIL,
	BPL,
	SPL,

	AX,
	BX,
	CX,
	DX,
	SI,
	DI,
	BP,
	SP,

	EAX,
	EBX,
	ECX,
	EDX,
	ESI,
	EDI,
	EBP,
	ESP,

	RAX,
	RBX,
	RCX,
	RDX,
	RSI,
	RDI,
	RBP,
	RSP,

	R8b,
	R9b,
	R10b,
	R11b,
	R12b,
	R13b,
	R14b,
	R15b,

	R8w,
	R9w,
	R10w,
	R11w,
	R12w,
	R13w,
	R14w,
	R15w,

	R8d,
	R9d,
	R10d,
	R11d,
	R12d,
	R13d,
	R14d,
	R15d,

	R8,
	R9,
	R10,
	R11,
	R12,
	R13,
	R14,
	R15,

	// hack
	UNPROMOTABLE,

	// high addressable bits
	AH,
	RIP,
};

enum X64_Instruction {
	ADD     = 0x01,
	SUB 	= 0x28,
	MOV     = 0x89,
	RET     = 0xc3,

	PUSH 	= 0x50,
	POP 	= 0x58,

	SEGCS   = 0x2E,

	NOP     = SEGCS,

	CALL    = 0xE8,
	JMP     = 0xE9,
	JMPS    = 0xEB,
	LEA     = 0x8D,

	JC      = 0x72,
	JB      = 0x72,
	JE      = 0x74,
	JNE     = 0x75,
	JL      = 0x7c,
	JGE     = 0x7d,
	JLE     = 0x7e,
	JG      = 0x7f,
};
