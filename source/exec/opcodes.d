module exec.instruction;

import std.bitmanip;
import std.conv;

static enum OP : ushort {
	DIE,

	// pushes the given value to the
	// operand stack.
	PSH,
	PSHS,
	PSHI,
	PSHL,

	// store the value on the stack
	// in the locals
	ALLOCI,

	// store the given operand on the
	// stack into the locals of the
	// current stack frame at the given addr
	STR,
	STRS,
	STRI,
	STRL,

	// pops the given operand from the stack
	POP,
	POPS,
	POPI,
	POPL,

	// pops and adds the top two values
	// on the operand stack, pushes
	// the result
	ADD,
	ADDS,
	ADDI,
	ADDL,

	// pops the two values and compares them
	// if equal pushes a 1, if not equal pushes a 0
	// note that the comparison result pushed to the stack is
	// always a byte!
	CMP,
	CMPS,
	CMPI,
	CMPL,

	// pops top two values a, b.
	// a > b pushes 1 to stack, else 0
	GTR,
	GTRS,
	GTRI,
	GTRL,

	// less than
	LT,
	LTS,
	LTI,
	LTL,

	// pops and subtract the top two values
	// on the operand stack, pushes
	// the result
	SUB,
	SUBS,
	SUBI,
	SUBL,

	// pops and multiplies the top two values
	// on the operand stack, pushes
	// the result
	MUL,
	MULS,
	MULI,
	MULL,

	// pops and divides the top two values
	// on the operand stack, pushes
	// the result
	DIV,
	DIVS,
	DIVI,
	DIVL,

	// loads a local from the given
	// address onto the stack.
	LD,
	LDS,
	LDI,
	LDL,

	// sets up a new stack frame, will
	// set the return address to the
	// last frame on the stack
	ENTR,

	// pops the current frame, if there
	// is a return address, jumps to that 
	// instruction.
	RET,

	AND,
	OR,

	// same as RET, though the given
	// value is pushed onto the callers
	// stack.
	RETV,

	// JE {addr}?
	JE,

	// JNE {addr}?
	JNE,

	// calls a native func
	NCALL,

	// calls 
	CALL,

	LEA,

	GOTO
}

struct Instruction {
	OP id;

	ubyte[] data;

	this(ubyte[] data) {
		// the id of the instruction is copied from
		// the first two bytes of the data we pass thru.
		this.id = cast(OP)(data.peek!(ushort, Endian.bigEndian));
		this.data = data;
	}

	T peek(T)(uint offs = 0) {
		// offset by the id
		return data[(offs + id.sizeof) .. $].peek!(T);
	}

	void put(T)(T val) {
		data.append!(T)(val);
	}
}

static Instruction encode(OP, T...)(OP id, T values) {
	import std.array;

	auto buff = appender!(ubyte[])();
	buff.append!ushort(cast(ushort)(id));
	foreach (val; values) {
		buff.append!T(val);
	}
	return Instruction(buff.data);
}
