module gen.x64.instr;

enum X64_Register : ubyte {
	AL,
	CL,
	DL,
	BL,
	SPL,
	BPL,
	SIL,
	DIL,

	AX,
	CX,
	DX,
	BX,
	SP,
	BP,
	SI,
	DI,

	EAX,
	ECX,
	EDX,
	EBX,
	ESP,
	EBP,
	ESI,
	EDI,

	RAX,
	RCX,
	RDX,
	RBX,
	RSP,
	RBP,
	RSI,
	RDI,
	RIP,

	R8,
	R9,
	R10,
	R11,
	R12,
	R13,
	R14,
	R15,

	XMM0,
	XMM1,
	XMM2,
	XMM3,
	XMM4,
	XMM5,
	XMM6,
	XMM7,
	XMM15,
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
