module ssa.instr;

import std.stdio;
import std.conv;

import krug_module : Token;
import ssa.block;
import sema.type;
import ast;

interface Instruction {
	Type get_type();
	string to_string();
}

class Basic_Instruction : Instruction {
	protected Type type;

	this(Type type) {
		this.type = type;
	}

	string to_string() {
		return to!string(type);
	}

	Type get_type() {
		return type;
	}
}

interface Value {}

class Constant {
	ast.Expression_Node value;
}

class Function {
	string name;
	Alloc[] locals;
	Basic_Block[] blocks;

	Basic_Block push_block() {
		auto block = Basic_Block(this);
		blocks ~= block;
		return block;
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
class Alloc : Basic_Instruction {
	this(Type type) {
		super(type);
	}
}

// *a = b
class Store : Basic_Instruction {
	this(Type type) {
		super(type);
	}

	Value address;
	Value val;
}

class BinaryOp : Basic_Instruction {
	this(Type type) {
		super(type);
	}

	Token op;
	Value a, b;
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