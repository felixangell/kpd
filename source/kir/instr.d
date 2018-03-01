module kir.instr;

import std.stdio;
import std.conv;

import ast;
import krug_module : Token;
import sema.type;
import ast;

interface Instruction {
	Type get_type();
}

class Basic_Block {
	Basic_Block[] preds;
	Basic_Block[] succs;

	ulong id;

	Instruction[] instructions;
	Function parent;

	this(Function parent) {
		this.parent = parent;
		this.id = parent.blocks.length;
	}

	void dump() {
		writeln("_bb", to!string(id), ":");
		foreach (instr; instructions) {
			writeln(" ", to!string(instr));
		}
	}

	void add_instr(Instruction instr) {
		instructions ~= instr;
	}
}

class Basic_Instruction : Instruction {
	protected Type type;

	this(Type type) {
		this.type = type;
	}

	override string toString() {
		return to!string(type);
	}

	Type get_type() {
		return type;
	}
}

interface Value {
	Type get_type();
}

class Basic_Value : Value {
	protected Type type;

	this(Type type) {
		this.type = type;
	}

	override string toString() {
		return to!string(type);
	}

	Type get_type() {
		return type;
	}
}

class Identifier : Basic_Value {
	string name;

	this(string name) {
		super(null); // fixme
		this.name = name;
	}

	override string toString() {
		return "iden(" ~ name ~ ")";
	}
}

class Constant : Basic_Value {
	ast.Expression_Node value;

	this (Type t, ast.Expression_Node value) {
		super(t);
		this.value = value;
	}

	override string toString() {
		if (auto i = cast(ast.Integer_Constant_Node) value) {
			return to!string(i.value);
		}

		return to!string(value);
	}
}

class Function {
	string name;
	Alloc[] locals;
	Basic_Block[] blocks;
	Basic_Block curr_block;

	Basic_Block push_block() {
		auto block = new Basic_Block(this);
		blocks ~= block;
		curr_block = block;
		return block;
	}

	// this is the assumption that
	// the first basic block in a function
	// is the entry block, we are adding
	// all of the allocations to this part!
	Value add_alloc(Alloc a) {
		blocks[0].add_instr(a);
		return a;
	}

	void add_instr(Instruction i) {
		curr_block.add_instr(i);
	}

	void dump() {
		writeln(name, "():");
		foreach (block; blocks) {
			block.dump();
		}
	}
}

class Phi {
	Value[] edges;
}

// a = new int
class Alloc : Basic_Instruction, Value {
	string name;

	this(Type type, string name) {
		super(type);
		this.name = name;
	}

	override Type get_type() {
		return type;
	}

	override string toString() {
		return "%" ~ name ~ " = new " ~ to!string(type);
	}
}

// *a = b
class Store : Basic_Instruction {
	Value address;
	Value val;

	this(Type type, Value address, Value val) {
		super(type);
		this.address = address;
		this.val = val;
	}

	override string toString() {
		string addr = to!string(address);
		if (auto alloc = cast(Alloc) address) {
			addr = "%" ~ alloc.name;
		}
		return "store " ~ to!string(val) ~ " -> " ~ to!string(addr);
	}
}

class BinaryOp : Basic_Instruction, Value {
	Token op;
	Value a, b;

	this(Type type, Token op, Value a, Value b) {
		super(type);
		this.op = op;
		this.a = a;
		this.b = b;
	}

	override Type get_type() {
		return type;
	}

	override string toString() {
		return to!string(a) ~ " " ~ op.lexeme ~ " " ~ to!string(b);
	}
}

class UnaryOp : Basic_Instruction {
	this(Type type) {
		super(type);
	}

	Token op;
	Value a;
}

class Jump {

}

class Return : Basic_Instruction {
	this(Type type) {
		super(type);
	}

	Value[] results;
}