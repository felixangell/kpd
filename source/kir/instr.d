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

	// todo dlang get thingy?
	string name() {
		return "_bb" ~ to!string(id);
	}

	void dump() {
		writeln("_bb", to!string(id), ":");
		foreach (instr; instructions) {
			writeln(" ", to!string(instr));
		}
	}

	Instruction add_instr(Instruction instr) {
		instructions ~= instr;
		return instr;
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

	this(Type type, string name) {
		super(type); // fixme
		this.name = name;
	}

	override string toString() {
		return "$" ~ name;
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

	Instruction add_instr(Instruction i) {
		return curr_block.add_instr(i);
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

// a op b
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

// op a
class UnaryOp : Basic_Instruction {
	this(Type type) {
		super(type);
	}

	Token op;
	Value a;
}

// jump <label>
class Jump : Basic_Instruction {
	Label label;

	this(Label label) {
		super(prim_type("void"));
		this.label = label;
	}

	override string toString() {
		return "jmp " ~ to!string(label);
	}
}

class Label : Basic_Value {
	string name;
	Basic_Block reference;

	this(Basic_Block bb) {
		super(prim_type("void"));
		this.name = bb.name();
		this.reference = bb;
	}

	this(string name, Basic_Block reference) {
		super(prim_type("void"));
		this.name = name;
		this.reference = reference;
	}

	override string toString() {
		return "#" ~ name;
	}
}

//              a 			 b
// if <cond> <label> else <label>
class If : Basic_Instruction {
	Value condition;
	Label a, b;

	this(Value condition) {
		super(prim_type("bool")); // ?
		this.condition = condition;
	}

	override string toString() {
		return "if " ~ to!string(condition) ~ " goto " ~ to!string(a) ~ " else " ~ to!string(b);
	}
}

// ret T [val]
class Return : Basic_Instruction {
	Value[] results;

	this(Type type) {
		super(type);
	}

	void set_type(Type type) {
		this.type = type;
	}

	override string toString() {
		string values_str = "";
		if (results !is null) {
			foreach (i, r; results) {
				if (i > 0) values_str ~= ", ";
				values_str ~= to!string(r);
			}
		}
		return "ret " ~ to!string(type) ~ " " ~ values_str;
	}
}