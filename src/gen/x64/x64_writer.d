module gen.x64.x64_writer;

import std.conv : to;
import std.bitmanip;

import gen.x64.instr;
import gen.x64.output;
import gen.x64.formatter;

// like the obj writer but this spits out
// assembly text instead.
// note make some kind of interface-y
// so theres less dupe code

class Memory_Location {

}

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

	this(long offs, X64_Register reg) {
		this.offs = offs;
		this.reg = reg;
	}

	this(string iden, X64_Register reg) {
		this.iden = iden;
		this.reg = reg;
	}
}

Reg[X64_Register] register_cache;

Reg get_reg(X64_Register r) {
	if (r in register_cache) {
		return register_cache[r];
	}
	auto val = new Reg(r);
	register_cache[r] = val;
	return val;
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
	void mov(Reg src, Address dest) {
		emitt("mov{} {}, {}", reg(src.reg), addr(dest));
	}

	void mov(Reg src, Reg dest) {
		emitt("mov{} {}, {}", suffix(src.reg.get_width()), reg(src.reg), reg(dest.reg));
	}

	void add_reg_reg(X64_Register src, X64_Register dest) {

	}

	void sub_reg_reg(X64_Register src, X64_Register dest) {

	}

	void ret() {
		emitt("ret");
	}

	void mov_int_reg(string value, X64_Register reg) {

	}

	void sub_val_reg(X64_Register reg, ulong value){

	}

	void xor(X64_Register a, X64_Register b) { 
	}

	void jmp(string iden) {

	}

	void je(string iden) {

	}

	void jne(string iden) {

	}

	void cmp(Memory_Location l, X64_Register r) {

	}

	void push(X64_Register r) {
		emitt("push{} {}", suffix(r.get_width()), reg(r));
	}

	void pop(X64_Register r) {
		emitt("pop{} {}", suffix(r.get_width()), reg(r));
	}

	void call(string addr) {

	}

	void syscall() {
		emitt("syscall");
	}

}