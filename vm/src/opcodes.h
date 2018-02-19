#ifndef OPCODES_H
#define OPCODES_H

enum OP {
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
};

#endif