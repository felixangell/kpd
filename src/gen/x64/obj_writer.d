module gen.x64.obj_writer;

import std.conv : to;
import std.bitmanip;

import gen.x64.formatter;

enum X64_Register : ubyte {
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
	ADD     = 0x01,
	SUB 	= 0x28,
	MOV     = 0x89,
	RET     = 0xc3,

	PUSH 	= 0x50,
	POP 	= 0x58,

	// .. 

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
//
//
// TODO:
// - mov_val_reg
// - add_val_reg
// - sub_val_reg
// - je, jne
// - cmp
// - set
// - lea
// 
// ... the rest
// but that covers most of the 
// instructions currently in use
// in the x64 backend.
class Object_Writer {
	// purely for debugging purposes
	string[] asm_code;

	ubyte[] object_file;

	void write_asm(string fmt, string[] s...) {
		asm_code ~= sfmt(fmt, s);
	}

	ubyte encode_rex(bool is_64bit, ubyte ext_sib_idx, ubyte ext_modrm_reg, ubyte ext_modrm_rm) {
		struct REX {
			mixin(bitfields!(
		        ubyte, "b", 1,
		        ubyte, "x", 1,
		        ubyte, "r", 1,
		        ubyte, "w", 1,
		        ubyte, "f", 4,
			));
		}

		REX r;
		r.b = ext_modrm_rm;
		r.x = ext_modrm_reg;
		r.r = ext_sib_idx;
		r.w = cast(ubyte) is_64bit;
		r.f = 0b100;
		return *(cast(ubyte*)(&r));
	}

	ubyte encode_modrm(ubyte mod, ubyte rm, ubyte reg){
		assert(reg < X64_Register.R8);
		assert(rm < X64_Register.R8);

		struct ModRM {
			mixin(bitfields!(
				ubyte, "rm", 3,
				ubyte, "reg", 3,
				ubyte, "mod", 2,
			));
		}
		
		ModRM m;
		m.rm = rm;
		m.reg = reg;
		m.mod = mod;
		return *(cast(ubyte*)&m);
	}

	ubyte encode_sib(ubyte scale, ubyte index, ubyte base){
		struct SIB {
			mixin(bitfields!(
				ubyte, "base", 3,
				ubyte, "index", 3,
				ubyte, "scale", 2,
			));
		}

		SIB s;
		s.scale = scale;
		s.index = index;
		s.base = base;
		return *(cast(ubyte*)&s);
	}

	ubyte encode_disp8(ulong value){
		assert(value <= 0xff);
		return cast(ubyte) value;
	}

	void mov_reg_reg(X64_Register src, X64_Register dest) {
		write_asm("mov {}, {}", to!string(src), to!string(dest));
		
		ubyte[3] encoded_instr;
		encoded_instr[0] = encode_rex(true, 0, 0, 0);
		encoded_instr[1] = X64_Instruction.MOV;
		encoded_instr[2] = encode_modrm(3, dest, src);
		object_file ~= encoded_instr;
	}

	void add_reg_reg(X64_Register src, X64_Register dest) {
		write_asm("mov {}, {}", to!string(src), to!string(dest));
		
		ubyte[3] encoded_instr;
		encoded_instr[0] = encode_rex(true, 0, 0, 0);
		encoded_instr[1] = X64_Instruction.ADD;
		encoded_instr[2] = encode_modrm(3, dest, src);
		object_file ~= encoded_instr;
	}

	void sub_reg_reg(X64_Register src, X64_Register dest) {
		write_asm("mov {}, {}", to!string(src), to!string(dest));
		
		ubyte[3] encoded_instr;
		encoded_instr[0] = encode_rex(true, 0, 0, 0);
		encoded_instr[1] = X64_Instruction.SUB;
		encoded_instr[2] = encode_modrm(3, dest, src);
		object_file ~= encoded_instr;
	}

	void ret() {
		write_asm("ret");
		// FIXME
		object_file ~= X64_Instruction.RET;
	}

	// mov $x, reg
	void mov_int_reg(string value, X64_Register reg) {
		write_asm("mov ${}, {}", value, to!string(reg));
	}

	// sub $x, reg
	void sub_val_reg(X64_Register reg, ulong value){
		ubyte[4] encoded_instr;
		encoded_instr[0] = encode_rex(1, 0, 0, 0);
		encoded_instr[1] = X64_Instruction.SUB;
		encoded_instr[2] = encode_modrm(3, reg, X64_Register.BP);
		encoded_instr[3] = encode_disp8(value);
		object_file ~= encoded_instr;
	}

	// push reg
	void push_reg(X64_Register reg) {
		write_asm("push {}", to!string(reg));
		// FIXME 
		// this seems to work for the 64 bit registers
		// so that does it for now.
		object_file ~= cast(ubyte)(X64_Instruction.PUSH + reg);
	}

	// pop reg
	void pop_reg(X64_Register reg) {
		write_asm("pop {}", to!string(reg));
		// FIXME 
		// this seems to work for the 64 bit registers
		// so that does it for now.
		object_file ~= cast(ubyte)(X64_Instruction.POP + reg);
	}

	void call(string addr) {

	}

	void syscall() {
		write_asm("syscall");
		// FIXME?
		object_file ~= [0x0f, 0x05];
	}
}

unittest {
	import std.stdio;

	void test_mov_reg_reg() {
		auto writer = new Object_Writer;
		writer.mov_reg_reg(X64_Register.AX, X64_Register.DI);
		foreach (c; writer.object_file) {
			writef("%2x ", c);
		}
		writeln;
	}

	void test_push_reg() {
		auto writer = new Object_Writer;
		
		writer.push_reg(X64_Register.AX);
		writer.push_reg(X64_Register.DI);
		writer.push_reg(X64_Register.BP);
		writer.push_reg(X64_Register.SI);

		foreach (i, c; writer.object_file) {
			writefln("%2x", c);
		}
	}

	void test_pop_reg() {
		auto writer = new Object_Writer;
		
		writer.pop_reg(X64_Register.AX);
		writer.pop_reg(X64_Register.DI);
		writer.pop_reg(X64_Register.BP);
		writer.pop_reg(X64_Register.SI);

		foreach (i, c; writer.object_file) {
			writefln("%2x", c);
		}
	}
	
	/*   0:	50                  push   %rax
   1:	57                   	push   %rdi
   2:	55                   	push   %rbp
   3:	56                   	push   %rsi
     4:	58                   	pop    %rax
   5:	5f                   	pop    %rdi
   6:	5d                   	pop    %rbp
   7:	5e                   	pop    %rsi
	*/
	test_push_reg();
	test_pop_reg();

}