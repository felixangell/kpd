module gen.x64.obj_writer;

import std.conv : to;

import gen.x64.formatter;

enum X64_Register {
	AX      = 0,
	CX      = 1,
	DX      = 2,
	BX      = 3,
	SP      = 4,
	BP      = 5,
	SI      = 6,
	DI      = 7,

	R8       = 8,
	R9       = 9,
	R10      = 10,
	R11      = 11,
	R12      = 12,
	R13      = 13,
	R14      = 14,
	R15      = 15,

	XMM0    = 16,
	XMM1    = 17,
	XMM2    = 18,
	XMM3    = 19,
	XMM4    = 20,
	XMM5    = 21,
	XMM6    = 22,
	XMM7    = 23,
	// xmm8 ... 14
	XMM15   = 31,

	AL      = 0,
	CL      = 1,
	DL      = 2,
	BL      = 3,
	AH      = 4,
	CH      = 5,
	DH      = 6,
	BH      = 7,
};

enum X64_Instruction {
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
	JL      = 0x7C,
	JGE     = 0x7D,
	JLE     = 0x7E,
	JG      = 0x7F,
};

enum REX_Prefix {
	REX     = 0x40,
	REX_W   = 8,
	REX_R   = 4,
	REX_X   = 2,
	REX_B   = 1,
};

// This is an object writer for x86_64
// assembly! TODO: have some inheritance-y
// thing or modular thingy for multiple architectures
// i.e. x64
class Object_Writer {
	// purely for debugging purposes
	string[] asm_code;

	void write_asm(string fmt, string[] s...) {
		asm_code ~= sfmt(fmt, s);
	}

	void mov_reg_reg(X64_Register a, X64_Register b) {
		write_asm("mov {}, {}", to!string(a), to!string(b));
	}

	void ret() {
		write_asm("ret");
	}

	// mov $x, reg
	void mov_int_reg(string value, X64_Register reg) {
		write_asm("mov ${}, {}", value, to!string(reg));
	}

	// sub $x, reg
	void sub_val_reg(string value, X64_Register reg) {
		write_asm("reg ${}, {}", value, to!string(reg));
	}

	// push reg
	void push_reg(X64_Register reg) {
		write_asm("push {}", to!string(reg));
	}

	// pop reg
	void pop_reg(X64_Register reg) {
		write_asm("pop {}", to!string(reg));
	}

	void call(string addr) {

	}

	void syscall() {
		write_asm("syscall");
	}
}

unittest {
	Object_Writer writer;
	writer.mov_int_reg("300", RAX);
	writer.mov_int_reg("60", RDI);
}