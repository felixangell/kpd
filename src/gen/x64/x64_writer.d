module gen.x64.asm_writer;

import std.stdio;
import std.conv : to;
import std.bitmanip;
import std.algorithm.comparison : min, max;
import std.uni : toLower;
import std.math : log2;

import gen.x64.instr;
import gen.x64.asm_file;
import gen.x64.formatter;

class Memory_Location {
	uint val_width;

	uint width() {
		return this.val_width;
	}

	void set_width(uint width) {
		this.val_width = width;
	}

	abstract string emit();
}

class Reg : Memory_Location {
	X64_Register value;

	this(X64_Register value) {
		this.value = value;
	}

	void promote(int widthInBytes) {
		// this shouldnt happen!
		if (widthInBytes > 8) {
			writeln(" width is " ~ to!string(widthInBytes));
			// widthInBytes = 8;
		}

		// 0, 1, 2, 4, 8
		//
		// log2(1) = 0
		// log2(2) = 1
		// log2(4) = 2
		// log2(8) = 3

		if (value >= X64_Register.UNPROMOTABLE) {
			return;
		}

		// we can only promote 1 byte registers
		// note that we could change it to do
		// promotions from a 4 byte to an 8 byte
		// but this is a TODO...
		if (width() != 1) {
			return;
		}

		ubyte offs = cast(ubyte)(log2(widthInBytes));

		auto new_value = cast(X64_Register)(cast(ubyte)(value + (offs*8)));
		if (new_value < X64_Register.UNPROMOTABLE) {
			value = new_value;
		}
	}

	override uint width() {
		if (value >= X64_Register.R8) {
			return 8;
		}
		else if (value >= X64_Register.R8d) {
			return 4;
		}
		else if (value >= X64_Register.R8w) {
			return 2;
		}
		else if (value >= X64_Register.R8b) {
			return 1;
		}

		else if (value >= X64_Register.RAX) {
			return 8;
		}
		else if (value >= X64_Register.EAX) {
			return 4;
		}
		else if (value >= X64_Register.AX) {
			return 2;
		}
		else if (value >= X64_Register.AL) {
			return 1;
		}

		assert(0, "unhandled " ~ to!string(value));
	}

	override string emit() {
		return "%" ~ to!string(value).toLower;
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

// seg:displace(reg, index, scale)
class Address : Memory_Location {
	long disp;
	long offs;
	string iden;

	Reg reg;
	Reg index;
	ulong scale;

	this(Reg r) {
		this.reg = r;
		this.iden = "";
	}

	this(long disp, Reg r) {
		this.disp = disp;
		this.reg = r;
	}

	this(string iden, Reg r) {
		this.iden = iden;
		this.reg = r;
	}

	override string emit() {
		reg.promote(8); // 8 byte

		// adjust offset by width
		offs *= width();

		if (iden.length > 0) {
			return iden ~ "(" ~ reg.emit() ~ ")";
		}
		
		if (index !is null) {
			index.promote(8);

			if (scale > 0) {
				// n(a, b, c)
				return sfmt("{}({}, {}, {})", to!string(disp + offs), reg.emit(), index.emit(), to!string(scale));
			}

			// n(a, b)
			return sfmt("{}({}, {})", to!string(disp + offs), reg.emit(), index.emit());
		}

		// n(a)
		return sfmt("{}({})", to!string(disp + offs), reg.emit());
	}

	override string toString() {
		return emit();
	}
}

string type_name(uint width) {
	switch (width) {
	case 8:
		return "quad";
	case 4:
		return "long";
	case 2:
		return "short";
	case 1:
		return "byte";
	default:
		return "";
	}
}

string suffix(uint width) {
	if (width == 0) {
		return "b";
	}
	
	// no suffix for this instr
	if (width == 2) {
		return "";
	}

	return to!string(type_name(width)[0]);
}

uint nzmax(uint a, uint b) {
	// pick non zero
	if (a == 0) {
		return b;
	}
	if (b == 0) {
		return a;
	}

	if (a > b) {
		return a;
	}
	return b;
}

uint nzmin(uint a, uint b) {
	// pick non zero
	if (a == 0) {
		return b;
	}
	if (b == 0) {
		return a;
	}

	if (a < b) {
		return a;
	}
	return b;
}

class X64_Assembly_Writer : X64_Assembly {

	void mov(Memory_Location src, Address dest) {
		emitt("mov{} {}, {}", suffix(src.width()), src.emit(), dest.emit());
	}

	void mov(Reg src, Reg dest) {
		emitt("mov{} {}, {}", suffix(src.width()), src.emit(), dest.emit());
	}

	void mov(Reg src, Memory_Location dest) {
		src.promote(src.width());
		emitt("mov{} {}, {}", suffix(src.width()), src.emit(), dest.emit());
	}

	// mov 0(%rsp), %rax
	void mov(Address src, Reg dest) {
		dest.promote(src.width());
		emitt("mov{} {}, {}", suffix(src.width()), src.emit(), dest.emit());
	}

	// mov %rax, 0(%rsp)
	void mov(Reg src, Address dest) {
		src.promote(src.width());
		emitt("mov{} {}, {}", suffix(src.width()), src.emit(), dest.emit());
	}

	// movz %rax, %rax
	void movz(Reg a, Reg b) {
		emitt("movz{} {}, {}", suffix(a.width()), a.emit(), b.emit());
	}

	// mov $1, 0(%rsp)
	void mov(Const src, Address dest) {
		emitt("mov{} {}, {}", suffix(dest.width()), src.emit(), dest.emit());
	}

	// mov $1, %rax
	void mov(Const src, Reg dest) {
		emitt("mov{} {}, {}", suffix(dest.width()), src.emit(), dest.emit());
	}

	// mov mem, %rax
	void mov(Memory_Location src, Reg dest) {
		dest.promote(src.width());
		emitt("mov{} {}, {}", suffix(dest.width()), src.emit(), dest.emit());
	}

	void lea(Memory_Location a, Reg b) {
		b.promote(8);
		emitt("leaq {}, {}", a.emit(), b.emit());
	}

	void and(Memory_Location a, Reg b) {
		emitt("and{} {}, {}", suffix(a.width()), a.emit(), b.emit());
	}

	void or(Memory_Location a, Reg b) {
		emitt("or{} {}, {}", suffix(a.width()), a.emit(), b.emit());
	}

	void subsd(Memory_Location a, Reg b) {
		assert(0);
	}

	void sub(Memory_Location a, Reg b) {
		emitt("sub{} {}, {}", suffix(b.width()), a.emit(), b.emit());
	}

	void addsd(Memory_Location a, Reg b) {
		assert(0);
	}

	void add(Memory_Location a, Reg b) {
		emitt("add{} {}, {}", suffix(b.width()), a.emit(), b.emit());
	}

	void mulsd(Memory_Location a, Reg b) {
		assert(0);
	}

	void imul(Memory_Location a, Reg b) {
		emitt("imul{} {}, {}", suffix(b.width()), a.emit(), b.emit());
	}

	void divsd(Memory_Location a, Reg b) {
		assert(0);
	}

	void idiv(Reg b) {
		emitt("idiv{} {}", suffix(b.width()), b.emit());
	}

	void cmp(Const a, Memory_Location b) {
		emitt("cmp{} {}, {}", suffix(a.width()), a.emit(), b.emit());
	}

	void cmp(Memory_Location a, Reg b) {
		emitt("cmp{} {}, {}", suffix(a.width()), a.emit(), b.emit());
	}

	void ret() {
		emitt("ret");
	}

	void setg(Reg m) {
		emitt("sete {}", m.emit());
	}

	void setb(Reg m) {
		emitt("setb {}", m.emit());
	}

	void setge(Reg m) {
		emitt("setge {}", m.emit());
	}

	void setle(Reg m) {
		emitt("setle {}", m.emit());
	}

	void sete(Reg m) {
		emitt("sete {}", m.emit());
	}

	void setne(Reg m) {
		emitt("setne {}", m.emit());
	}

	void xor(Const a, Reg b) {
		emitt("xor {}, {}", a.emit(), b.emit());
	}

	void xor(Reg a, Reg b) {
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

	void push(Reg r) {
		emitt("push{} {}", suffix(r.width()), r.emit());
	}

	void pop(Reg r) {
		emitt("pop{} {}", suffix(r.width()), r.emit());
	}

	void call(string addr) {
		emitt("call {}", addr);
	}

	void syscall() {
		emitt("syscall");
	}

}