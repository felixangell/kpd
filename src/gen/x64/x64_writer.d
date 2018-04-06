module gen.x64.x64_writer;

import std.conv : to;
import std.bitmanip;
import std.algorithm.comparison : min, max;
import std.uni : toLower;

import gen.x64.instr;
import gen.x64.output;
import gen.x64.formatter;

// GROSS!
Reg AL; Reg CL; Reg DL; Reg BL; Reg SPL; Reg BPL; Reg SIL; Reg DIL; 
Reg AX; Reg CX; Reg DX; Reg BX; Reg SP; Reg BP; Reg SI; Reg DI; 
Reg EAX; Reg ECX; Reg EDX; Reg EBX; Reg ESP; Reg EBP; Reg ESI; Reg EDI; 
Reg RAX; Reg RCX; Reg RDX; Reg RBX; Reg RSP; Reg RBP; Reg RSI; Reg RDI; Reg RIP; 
Reg R8; Reg R9; Reg R10; Reg R11; Reg R12; Reg R13; Reg R14; Reg R15; 
Reg XMM0; Reg XMM1; Reg XMM2; Reg XMM3; Reg XMM4; Reg XMM5; Reg XMM6; Reg XMM7; Reg XMM15;

static this() {
	AL = new Reg(X64_Register.AL);
	CL = new Reg(X64_Register.CL);
	DL = new Reg(X64_Register.DL);
	BL = new Reg(X64_Register.BL);
	SPL = new Reg(X64_Register.SPL);
	BPL = new Reg(X64_Register.BPL);
	SIL = new Reg(X64_Register.SIL);
	DIL = new Reg(X64_Register.DIL);
	AX = new Reg(X64_Register.AX);
	CX = new Reg(X64_Register.CX);
	DX = new Reg(X64_Register.DX);
	BX = new Reg(X64_Register.BX);
	SP = new Reg(X64_Register.SP);
	BP = new Reg(X64_Register.BP);
	SI = new Reg(X64_Register.SI);
	DI = new Reg(X64_Register.DI);
	EAX = new Reg(X64_Register.EAX);
	ECX = new Reg(X64_Register.ECX);
	EDX = new Reg(X64_Register.EDX);
	EBX = new Reg(X64_Register.EBX);
	ESP = new Reg(X64_Register.ESP);
	EBP = new Reg(X64_Register.EBP);
	ESI = new Reg(X64_Register.ESI);
	EDI = new Reg(X64_Register.EDI);
	RAX = new Reg(X64_Register.RAX);
	RCX = new Reg(X64_Register.RCX);
	RDX = new Reg(X64_Register.RDX);
	RBX = new Reg(X64_Register.RBX);
	RSP = new Reg(X64_Register.RSP);
	RBP = new Reg(X64_Register.RBP);
	RSI = new Reg(X64_Register.RSI);
	RDI = new Reg(X64_Register.RDI);
	RIP = new Reg(X64_Register.RIP);
	R8 = new Reg(X64_Register.R8);
	R9 = new Reg(X64_Register.R9);
	R10 = new Reg(X64_Register.R10);
	R11 = new Reg(X64_Register.R11);
	R12 = new Reg(X64_Register.R12);
	R13 = new Reg(X64_Register.R13);
	R14 = new Reg(X64_Register.R14);
	R15 = new Reg(X64_Register.R15);
	XMM0 = new Reg(X64_Register.XMM0);
	XMM1 = new Reg(X64_Register.XMM1);
	XMM2 = new Reg(X64_Register.XMM2);
	XMM3 = new Reg(X64_Register.XMM3);
	XMM4 = new Reg(X64_Register.XMM4);
	XMM5 = new Reg(X64_Register.XMM5);
	XMM6 = new Reg(X64_Register.XMM6);
	XMM7 = new Reg(X64_Register.XMM7);
	XMM15 = new Reg(X64_Register.XMM15);
}

class Memory_Location {
	abstract uint width();
	abstract string emit();
}

class Reg : Memory_Location {
	X64_Register reg;

	this(X64_Register reg) {
		this.reg = reg;
	}

	override uint width() {
		return get_width(reg);
	}

	override string emit() {
		return "%" ~ to!string(reg).toLower;
	}
}

class Const : Memory_Location {
	string val;

	this(string val) {
		this.val = val;
	}

	override string emit() {
		return "$" ~ val;
	}

	override uint width() {
		return 0;
	}
}

// TODO mangle this or something
// because there might be name collisionsm
// among modules.
uint[string] constant_sizes;

class Address : Memory_Location {
	long offs;
	string iden;

	Reg reg;

	this(long offs, Reg r) {
		this.offs = offs;
		this.reg = r;
	}

	this(string iden, Reg r) {
		this.iden = iden;
		this.reg = r;
	}

	override uint width() {
		if (iden.length > 0) {
			if (iden in constant_sizes) {
				return constant_sizes[iden];
			}
			return 0;
		}
		return reg.width();
	}

	override string emit() {
		if (iden.length > 0) {
			return iden ~ "(" ~ reg.emit() ~ ")";
		}
		return to!string(offs) ~ "(" ~ reg.emit() ~ ")";
	}
}

string type_name(uint width) {
	final switch (width) {
	case 8:
		return "quad";
	case 4:
		return "long";
	case 2:
		return "short";
	case 1:
		return "byte";
	}
}

string suffix(uint width) {
	return to!string(type_name(width)[0]);
}

uint get_width(X64_Register a) {
	if (a >= X64_Register.RAX) {
		return 8;
	}
	else if (a >= X64_Register.EAX) {
		return 4;
	}
	else if (a >= X64_Register.AX) {
		return 2;
	}
	else if (a >= X64_Register.AL) {
		return 1;
	}
	assert(0);
}

uint nzpick(uint a, uint b) {
	// pick non zero
	if (a == 0) {
		return b;
	}
	if (b == 0) {
		return a;
	}

	// otherwise pick smallest
	if (a < b) {
		return a;
	}
	return b;
}

class X64_Writer : X64_Code {
	// things to think about
	// movzb al, eax
	// movq rax, rax
	void mov(Memory_Location src, Memory_Location dest) {
		uint w = nzpick(src.width(), dest.width());
		emitt("mov{} {}, {}", suffix(w), src.emit(), dest.emit());
	}

	void add(Memory_Location val, Memory_Location dst) {
		uint w = max(val.width(), dst.width());
		emitt("add{} {}, {}", suffix(w), val.emit(), dst.emit());
	}

	void sub(Memory_Location val, Memory_Location dst) {
		uint w = max(val.width(), dst.width());
		emitt("sub{} {}, {}", suffix(w), val.emit(), dst.emit());
	}

	void ret() {
		emitt("ret");
	}

	void setg(Memory_Location m) {
		emitt("sete {}", m.emit());
	}

	void setb(Memory_Location m) {
		emitt("setb {}", m.emit());
	}

	void setge(Memory_Location m) {
		emitt("setge {}", m.emit());
	}

	void setle(Memory_Location m) {
		emitt("setle {}", m.emit());
	}

	void sete(Memory_Location m) {
		emitt("sete {}", m.emit());
	}

	void setne(Memory_Location m) {
		emitt("setne {}", m.emit());
	}

	void xor(Memory_Location a, Memory_Location b) {
		emitt("xor {}, {}", a.emit(), b.emit());
	}

	void jmp(string iden) {
		emitt("jmp {}", iden);
	}

	void je(string iden) {
		emitt("je {}", iden);
	}

	void jne(string iden) {
		emitt("jne {}", iden);
	}

	void cmp(Memory_Location val, Memory_Location r) {
		uint w = max(val.width(), r.width());
		emitt("cmp{} {}, {}", suffix(w), val.emit(), r.emit());
	}

	void push(Memory_Location r) {
		emitt("push{} {}", suffix(r.width()), r.emit());
	}

	void pop(Memory_Location r) {
		emitt("pop{} {}", suffix(r.width()), r.emit());
	}

	void call(string addr) {
		emitt("call {}", addr);
	}

	void syscall() {
		emitt("syscall");
	}

}