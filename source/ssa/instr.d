module ssa.instr;

import krug_module : Token;
import ssa.block;
import sema.type;
import ast;

interface Instruction {
	Type get_type();
}

interface Value {}

class Constant {
	ast.Expression_Node value;
}

class Function {
	string name;
	Alloc[] locals;
	Basic_Block[] blocks;
}

class Phi {
	Value[] edges;
}

// a = new int
class Alloc {
	
}

// *a = b
class Store {
	Value address;
	Value val;
}

class BinaryOp {
	Token op;
	Value a, b;
}

class UnaryOp {
	Token op;
	Value a;
}

class Jump {

}

class Return {
	Value[] results;
}