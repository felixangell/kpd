module ssa.instr;

import std.stdio;
import std.conv;

import ast;
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

class Identifier : Value {
	string name;

	this(string name) {
		this.name = name;
	}

	override string toString() {
		return "iden(" ~ name ~ ")";
	}
}

class Constant : Value {
	ast.Expression_Node value;

	this (ast.Expression_Node value) {
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
	Value address;
	Value val;

	this(Type type, Value address, Value val) {
		super(type);
		this.address = address;
		this.val = val;
	}

	override string toString() {
		return "store " ~ to!string(val) ~ " -> " ~ to!string(address);
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