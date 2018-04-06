module gen.x64.x64_writer;

import std.conv : to;
import std.bitmanip;

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

class Memory_Location {}

class Reg : Memory_Location {
	X64_Register reg;

	this(X64_Register reg) {
		this.reg = reg;
	}
}

class Const : Memory_Location {
	string val;

	this(string val) {
		this.val = val;
	}
}

class Address : Memory_Location {
	long offs;
	string iden;

	X64_Register reg;

	this(long offs, Reg r) {
		this.offs = offs;
		this.reg = r.reg;
	}

	this(string iden, Reg r) {
		this.iden = iden;
		this.reg = r.reg;
	}
}

string reg(X64_Register r) {
	// TODO lowercase
	return "%" ~ to!string(r);
}

string addr(Address a) {
	if (a.iden.length > 0) {
		return a.iden ~ "(" ~ reg(a.reg) ~ ")";
	}
	return to!string(a.offs) ~ "(" ~ reg(a.reg) ~ ")";
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

class X64_Writer : X64_Code {
	void mov(Memory_Location src, Memory_Location dest) {
		emitt("mov");
	}

	void add(Memory_Location val, Memory_Location dst) {
		emitt("add");
	}

	void ret() {
		emitt("ret");
	}

	void setg(Memory_Location m) {

	}

	void setb(Memory_Location m) {

	}

	void setge(Memory_Location m) {

	}

	void setle(Memory_Location m) {

	}

	void sete(Memory_Location m) {

	}

	void setne(Memory_Location m) {

	}

	void xor(Memory_Location a, Memory_Location b) {
		emitt("xor");
	}

	void jmp(string iden) {
		emitt("jmp");
	}

	void je(string iden) {
		emitt("je");
	}

	void jne(string iden) {
		emitt("jen");
	}

	void cmp(Memory_Location l, Memory_Location r) {
		emitt("cmp");
	}

	void push(Memory_Location r) {
		emitt("push");
	}

	void pop(Memory_Location r) {
		emitt("pop");
	}

	void call(string addr) {
		emitt("call");
	}

	void syscall() {
		emitt("syscall");
	}

}