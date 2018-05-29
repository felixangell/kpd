module kir.instr;

import std.stdio;
import std.conv;
import std.string;
import std.array : replicate;
import std.range.primitives;

import sema.type;
import kir.ir_mod;
import kir.cfg;
import ast;
import tok;

interface Instruction {
	Type get_type();
	void set_type(Type type);

	// TODO do we need this on _Every_
	// instruction? probably not, later
	// look at cases where this is necessary
	// and change accordingly. I feel like
	// this should only be necessary on
	// functions for now, but...

	// user annotations i.e.
	// #{no_mangle}
	Attribute[string] get_attributes();
	void set_attributes(Attribute[string] a);
	bool has_attribute(string s);

	void set_code(string s);
	string get_code();
}

interface Value {
	Type get_type();
	void set_type(Type t);
}

class Basic_Instruction : Instruction {
	protected Type type;
	protected string code;
	protected Attribute[string] dirs;

	void set_attributes(Attribute[string] dirs) {
		this.dirs = dirs;
	}
	Attribute[string] get_attributes() {
		return dirs;
	}

	bool has_attribute(string name) {
		return (name in dirs) !is null;
	}

	this(Type type) {
		this.type = type;
	}

	override void set_code(string s) {
		this.code = s;
	}

	override string get_code() {
		return code;
	}

	override string toString() {
		return to!string(type);
	}

	override void set_type(Type t) {
		this.type = t;
	}
	override Type get_type() {
		return type;
	}
}

class Basic_Value : Value {
	protected Type type;

	this(Type type) {
		this.type = type;
	}

	override string toString() {
		return to!string(type);
	}

	override void set_type(Type t) {
		this.type = t;
	}
	override Type get_type() {
		return type;
	}
}

struct Dom_Info {
	Basic_Block idom;
	Basic_Block[] children;
	int pre, post;
}

bool is_branching_instr(Instruction i) {
	return cast(Jump)i || cast(Return) i || cast(If) i;
}

class Basic_Block {
	ulong id;
	
	uint index = 0;
	Dom_Info dom;

	string namespace = "";

	Instruction[] instructions;
	Function parent;

	this(Function parent) {
		this.parent = parent;
		this.id = parent.blocks.length;
	}

	// todo dlang get thingy?
	string name() {
		return "bb" ~ to!string(id) ~ namespace;
	}

	Instruction last_instr() {
		if (instructions.length == 0) {
			return new NOP;
		}
		return instructions.back;
	}

	void dump() {
		writeln(name(), ":");
		foreach (instr; instructions) {
			auto code_sample = instr.get_code();
			if (code_sample != "") {
				code_sample = "; " ~ code_sample;
			}

			string ir_code = to!string(instr).strip();
			writefln("   %-80s%-80s", ir_code, code_sample);
		}
	}

	Instruction add_instr(Instruction instr) {
		instructions ~= instr;
		return instr;
	}
}

class Constant_Reference : Basic_Value {
	string name;

	this(Type type, string name) {
		super(type);
		this.name = name;
	}

	override string toString() {
		return "'" ~ name ~ ":" ~ to!string(get_type());
	}
}

class Identifier : Basic_Value {
	string name;

	this(Type type, string name) {
		super(type); // fixme
		this.name = name;
	}

	override string toString() {
		return name ~ ":" ~ to!string(get_type());
	}
}

class Index : Basic_Instruction, Value {
	Value addr;
	Value index;

	this(Type t, Value addr, Value index) {
		super(t);
		this.addr = addr;
		this.index = index;
	}

	override void set_type(Type t) {
		this.type = t;
	}
	override Type get_type() {
		return type;
	}

	override string toString() {
		return "index(" ~ to!string(addr) ~ " , " ~ to!string(index) ~ ")";
	}
}

class Composite : Basic_Value {
	Value[] values;

	this(Type t, Value[] values...) {
		super(t);
		this.values.length = values.length;
		foreach (v; values) {
			this.values ~= v;
		}
	}

	void add_value(Value val) {
		values ~= val;
	}

	override string toString() {
		string result = "";
		foreach (i, v; values) {
			if (i > 0) result ~= ",";
			result ~= to!string(v);
		}
		return "{" ~ result ~ "}";
	}
}

class Constant : Basic_Value {
	// how should we go around
	// storing this! for now it's strings
	string value;

	this(Type t, string value) {
		super(t);
		this.value = value;
	}

	override string toString() {
		return value ~ ":" ~ to!string(get_type());
	}
}

class Function : Basic_Instruction {
	IR_Module parent_mod;

	string name;
	Alloc[] locals;
	Alloc[] params;
	
	Control_Flow_Graph graph;

	Basic_Block[] blocks;

	Basic_Block curr_block;

	this(string name, Type return_type, IR_Module parent) {
		super(return_type);
		this.name = name;
		this.parent_mod = parent;
	}

	Basic_Block push_block(string namespace = "") {
		auto block = new Basic_Block(this);
		block.namespace ~= namespace;
		blocks ~= block;
		curr_block = block;
		return block;
	}

	// this is the assumption that
	// the first basic block in a function
	// is the entry block, we are adding
	// all of the allocations to this part!
	Value add_alloc(Alloc a) {
		assert(curr_block !is null);
		curr_block.add_instr(a);
		return a;
	}

	Instruction last_instr() {
		if (curr_block is null || curr_block.instructions.length == 0) {
			return new NOP;
		}
		return curr_block.instructions.back;
	}

	Instruction add_instr(Instruction i) {
		return curr_block.add_instr(i);
	}

	void dump() {
		string args;
		foreach (idx, p; params) {
			if (idx > 0) {
				args ~= ", ";
			}
			args ~= to!string(p.type);
		}

		write(name, "(" ~ args ~ "):");

		if (blocks.length > 0) {
			writeln(" #entry = ", blocks[0].name());
			foreach (block; blocks) {
				block.dump();
			}
		} else {
			writeln;
		}
	}
}

class Phi : Basic_Value {
	Value[] edges;
	Value[] users;

	this() {
		super(new Void());
	}

	void add_edge(Value v) {
		super.type = v.get_type();
		edges ~= v;
	}

	override string toString() {
		string edges_str;
		foreach (i, v; edges) {
			if (i > 0) edges_str ~= ',';
			edges_str ~= to!string(v);
		}
		return "phi(" ~ edges_str ~ ")";
	}
}

class Undef : Basic_Value {
	this() {
		super(new Void());
	}
}

// a = new int
class Alloc : Basic_Instruction, Value {
	string name;

	this(Type type, string name) {
		super(type);
		this.name = name;
	}

	override void set_type(Type t) {
		this.type = t;
	}
	override Type get_type() {
		return type;
	}

	override string toString() {
		return name ~ " = new " ~ to!string(type);
	}
}

// fixme this is a module call thing
class Module_Access : Basic_Instruction, Value {
	Identifier mod;
	Value right;

	this(Identifier mod, Value right) {
		super(right.get_type());
		this.mod = mod;
		this.right = right;
	}

	override void set_type(Type t) {
		this.type = t;
	}
	override Type get_type() {
		return type;
	}

	override string toString() {
		return "mod_invoke " ~ to!string(mod) ~ "." ~ to!string(right);
	}
}

class Call : Basic_Instruction, Value {
	Value left;
	Value[] args;

	this(Type type, Value left, Value[] args) {
		super(type);
		this.left = left;
		this.args = args;
	}

	override void set_type(Type t) {
		this.type = t;
	}
	override Type get_type() {
		return type;
	}

	override string toString() {
		string params;
		foreach (i, a; args) {
			if (i > 0)
				params ~= ", ";
			params ~= to!string(a);
		}
		return "invoke " ~ to!string(left) ~ "(" ~ params ~ ")";
	}
}

// *a = b
class Store : Basic_Instruction, Value {
	Value address;
	Value val;

	this(Type type, Value address, Value val) {
		super(type);
		this.address = address;
		this.val = val;
	}

	override void set_type(Type t) {
		this.type = t;
	}
	override Type get_type() {
		return type;
	}

	override string toString() {
		string addr = to!string(address);
		if (auto alloc = cast(Alloc) address) {
			addr = alloc.name;
		}
		return to!string(addr) ~ " = " ~ to!string(val);
	}
}

// a op b
class Binary_Op : Basic_Instruction, Value {
	string op;
	Value a, b;

	this(Type type, string op, Value a, Value b) {
		super(type);
		this.op = op;
		this.a = a;
		this.b = b;
	}

	this(Type type, Token op, Value a, Value b) {
		this(type, op.lexeme, a, b);
	}

	override void set_type(Type t) {
		this.type = t;
	}
	override Type get_type() {
		return type;
	}

	override string toString() {
		return to!string(a) ~ " " ~ op ~ " " ~ to!string(b);
	}
}

class Deref : Basic_Value {
	Value v;

	this(Value v) {
		// if v.get_type() is a ptr, this would be the ptrs base type.
		super(v.get_type());
		this.v = v;
	}

	override string toString() {
		return "@(" ~ to!string(v) ~ ")";
	}
}

// offs, index, scale
// returns a pointer to the given
// position to the addr 
// specified by the offs, index, scale
class Get_Element_Pointer : Basic_Value {
	Value addr;
	ulong index;
	int width;

	this(Value addr, ulong index, int width) {
		super(addr.get_type());
		this.addr = addr;
		this.index = index;
		this.width = width;
	}

	int get_width() {
		return width;
	}

	override string toString() {
		return "gep(" ~ to!string(addr) ~ ", " ~ to!string(index) ~ ")";
	}
}

class Addr_Of : Basic_Value {
	Value v;

	this(Value v) {
		super(new Pointer(v.get_type()));
		this.v = v;
	}

	override string toString() {
		return "&(" ~ to!string(v) ~ ")";
	}
}

class Builtin : Basic_Instruction, Value {
	Token op;
	Value v;

	this(Token op, Value v) {
		super(v.get_type());
		this.v = v;
		this.op = op;
	}
	
	override void set_type(Type t) {
		this.type = t;
	}
	override Type get_type() {
		return type;
	}

	override string toString() {
		return op.lexeme ~ "(" ~ to!string(v) ~ ")";
	}
}

// op a
class Unary_Op : Basic_Instruction, Value {
	Value v;
	Token op;

	this(Token op, Value v) {
		super(v.get_type());
		this.v = v;
		this.op = op;
	}

	override void set_type(Type t) {
		this.type = t;
	}
	override Type get_type() {
		return type;
	}

	override string toString() {
		return op.lexeme ~ "(" ~ to!string(v) ~ ")";
	}
}

class NOP : Basic_Instruction {
	this() {
		super(new Void());
	}
}

// jump <label>
class Jump : Basic_Instruction {
	Label label;

	this(Label label) {
		super(new Void());
		this.label = label;
	}

	bool fallthru = false;
	Jump setfallthru() {
		fallthru = true;
		return this;
	}

	override string toString() {
		return (fallthru ? "fallthrough" : "jmp") ~ " " ~ to!string(label);
	}
}

class Label : Basic_Value {
	string name;
	Basic_Block reference;

	this(Basic_Block bb) {
		super(new Void());
		this.name = bb.name();
		this.reference = bb;
	}

	this(string name, Basic_Block reference) {
		super(new Void());
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
		super(get_int(false, 8)); // FIXME ?
		this.condition = condition;
	}

	override string toString() {
		return "if " ~ to!string(condition) ~ " goto " ~ to!string(a) ~ " else " ~ to!string(
				b);
	}
}

// ret T [val]
class Return : Basic_Instruction {
	Value[] results;

	this(Type type) {
		super(type);
	}

	override string toString() {
		string values_str = "";
		if (results !is null) {
			foreach (i, r; results) {
				if (i > 0)
					values_str ~= ", ";
				values_str ~= to!string(r);
			}
		}
		return "ret " ~ to!string(type) ~ " " ~ values_str;
	}
}
