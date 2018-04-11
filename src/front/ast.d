module ast;

import std.typecons;
import std.conv;
import std.bigint;

import compiler_error;
import diag.engine;

import tok;
import logger;
import colour;
import sema.symbol;
import krug_module;

// binding of an expression to a token
alias Binding = Tuple!(Token, "twine", Expression_Node, "value");

interface Semicolon_Stat {}

alias AST = ast.Node[];

class Node {
	private Attribute[string] attribs;
	private Token_Info tok_info;

	Token_Info get_tok_info() {
		return tok_info;
	}

	void set_tok_info(Token start, Token end = null) {
		if (end is null) {
			tok_info = new Absolute_Token(start);
			return;
		}
		tok_info = new Token_Span(start, end);
	}

	Attribute[string] get_attribs() {
		return attribs;
	}
	void set_attribs(Attribute[string] a) {
		this.attribs = a;
	}
}

bool has_attribute(Node n, string name) {
	return (name in n.get_attribs()) !is null;
}

class Statement_Node : Node {

}

// examples...
// #{inline(always), rep(align=4)}
// #{repr(align="4")}

// attribute_value = identifier [ "=" (string | identifier) ]
class Attribute_Value {
	Token name;
	Token value; // optional value

	this(Token name) {
		this.name = name;
	}
}

// attribute = identifier [ "(" { attribute_value } ")" ]
class Attribute {
	Token name;
	Attribute_Value[] values;

	this(Token name) {
		this.name = name;
	}
}

// "let" "{" { iden "," } "}" "=" Expr
class Structure_Destructuring_Statement_Node : Statement_Node, Semicolon_Stat {
	Token[] values;
	Expression_Node rhand;
	bool mutable;
}

// "let" "(" { iden "," } ")" "=" Expr
class Tuple_Destructuring_Statement_Node : Statement_Node, Semicolon_Stat {
	Token[] values;
	Expression_Node rhand;
	bool mutable;
}

// defer ( stat )
class Defer_Statement_Node : Statement_Node {
	Statement_Node stat;

	this(Statement_Node stat) {
		this.stat = stat;
	}

	override string toString() {
		return "defer " ~ to!string(stat);
	}
}

class Match_Arm_Node : Node {
	Expression_Node[] expressions;
	Block_Node block;

	override string toString() {
		return "[" ~ to!string(expressions) ~ "] => " ~ to!string(block);
	}
}

class Match_Statement_Node : Statement_Node {
	Expression_Node condition;
	Match_Arm_Node[] arms;

	this(Expression_Node condition, Match_Arm_Node[] arms...) {
		this.condition = condition;
		this.arms = arms;
	}

	override string toString() {
		return "match " ~ to!string(arms);
	}
}

class Loop_Statement_Node : Statement_Node {
	Block_Node block;

	this(Block_Node block) {
		this.block = block;
	}

	override string toString() {
		return "loop";
	}
}

class While_Statement_Node : Statement_Node {
	Expression_Node condition;
	Block_Node block;

	this(Expression_Node condition, Block_Node block) {
		this.condition = condition;
		this.block = block;
	}

	override string toString() {
		return "while(" ~ to!string(condition) ~ ")";
	}
}

class If_Statement_Node : Statement_Node {
	Expression_Node condition;
	Block_Node block;

	this(Expression_Node condition, Block_Node block) {
		this.condition = condition;
		this.block = block;
	}

	override string toString() {
		return "if(" ~ to!string(condition) ~ ")";
	}
}

class Else_If_Statement_Node : Statement_Node {
	Expression_Node condition;
	Block_Node block;
	this(Expression_Node condition, Block_Node block) {
		this.condition = condition;
		this.block = block;
	}
}

class Else_Statement_Node : Statement_Node {
	Block_Node block;
	this(Block_Node block) {
		this.block = block;
	}
}

// return [ expr ] ";"
class Return_Statement_Node : Statement_Node, Semicolon_Stat {
	Expression_Node value;

	this(Expression_Node value) {
		this.value = value;
	}

	override string toString() {
		return "ret " ~ to!string(value);
	}
}

// break ";"
class Break_Statement_Node : Statement_Node, Semicolon_Stat {
	override string toString() {
		return "break";
	}
}

// next ";"
class Next_Statement_Node : Statement_Node, Semicolon_Stat {
	override string toString() {
		return "next";
	}
}

// yield Expression ";"
class Yield_Statement_Node : Statement_Node, Semicolon_Stat {
	Expression_Node value;

	this(Expression_Node value) {
		this.value = value;
	}

	override string toString() {
		return "yield";
	}
}

// "type" Identifier Type ";"
class Named_Type_Node : Statement_Node, Semicolon_Stat {
	Token twine;

	Type_Node type;

	this(Token twine, Type_Node type) {
		this.twine = twine;
		this.type = type;
	}
}

// {let|mut} name [ Type ] [ "=" Expression ] ";"
class Variable_Statement_Node : Statement_Node, Semicolon_Stat {
	Token twine;
	Type_Node type;
	Expression_Node value = null;
	bool mutable = false;

	this(Token twine, Type_Node type, bool mutable = false) {
		this.twine = twine;
		this.type = type;
		this.mutable = mutable;
	}

	override string toString() {
		return twine.lexeme ~ " : " ~ (type !is null ? to!string(type)
				: "_") ~ (value !is null ? " = " ~ to!string(value) : "");
	}
}

class Cast_Expression_Node : Expression_Node {
	Expression_Node left;
	Type_Node type;

	this(Expression_Node left, Type_Node type) {
		this.left = left;
		this.type = type;
	}

	override string toString() {
		return "(" ~ to!string(left) ~ "#" ~ to!string(type) ~ ")";
	}
}

// CONSTANTS

class Constant_Node(T) : Expression_Node {
	Token tok;
	T value;

	this(Token tok, T value) {
		this.tok = tok;
		this.value = value;
	}
}

static enum String_Type {
	C_STYLE,
	PASCAL_STYLE,
};

class String_Constant_Node : Constant_Node!string {
	String_Type type = String_Type.PASCAL_STYLE;

	this(Token tok) {
		super(tok, tok.lexeme);
		set_tok_info(tok);
	}

	override string toString() {
		return value;
	}
}

class Float_Constant_Node : Constant_Node!double {
	this(Token tok) {
		super(tok, to!double(tok.lexeme));
		set_tok_info(tok);
	}

	override string toString() {
		return to!string(value);
	}
}

class Integer_Constant_Node : Constant_Node!BigInt {
	this(Token tok) {
		super(tok, BigInt(tok.lexeme));
		set_tok_info(tok);
	}

	override string toString() {
		return to!string(value);
	}
}

class Boolean_Constant_Node : Constant_Node!bool {
	this(Token tok) {
		// TODO: what if token is something other
		// than "true"? this has to be validated before
		// we create the node.
		super(tok, tok.cmp("true") ? true : false);
		set_tok_info(tok);
	}

	override string toString() {
		return value ? "true" : "false";
	}
}

class Rune_Constant_Node : Constant_Node!dchar {
	this(Token tok) {
		super(tok, to!dchar(tok.lexeme[1]));
		set_tok_info(tok);
	}

	override string toString() {
		return "'" ~ to!string(value) ~ "'";
	}
}

// TOP LEVEL DECLARATION AST NODES

class Function_Node : Node {
	Token name;
	Type_Node return_type;
	Block_Node func_body;
	Variable_Statement_Node func_recv;
	Function_Parameter[] params;
	Generic_Set generics;

	override string toString() {
		string args;
		foreach (i, p; params) {
			if (i > 0) args ~= ",";
			args ~= to!string(p);
		}
		return "fn " ~ name.lexeme ~ "(" ~ args ~ ")";
	}
}

class Block_Node : Statement_Node {
	Statement_Node[] statements;
	Function_Node parent;
	Symbol_Table sym_table;

	this() {

	}
}

// EXPRESSION AST NODES

class Expression_Node : Statement_Node {
	Symbol_Value resolved_symbol = null;
}

class Call_Node : Expression_Node {
	Expression_Node left;
	Expression_Node[] args;

	// some_foo!int();
	// some_other!(int, double, Foo)();
	// some_blah!(int)();
	ast.Type_Path_Node[] generic_params;

	this(Expression_Node left) {
		this.left = left;
	}

	override string toString() {
		string arguments;
		foreach (i, a; args) {
			if (i > 0)
				arguments ~= ",";
			arguments ~= to!string(a);
		}
		return "(" ~ to!string(left) ~ ")(" ~ arguments ~ ")";
	}
}

class Symbol_Node : Expression_Node {
	Token value;

	this(Token value) {
		this.value = value;
		this.set_tok_info(value);
	}

	override string toString() const {
		return "[sym " ~ value.lexeme ~ "]";
	}
}

class Path_Expression_Node : Expression_Node {
	Expression_Node[] values;

	// the table in which the path was
	// resolved to.
	Symbol_Table resolved_to = null;

	override string toString() {
		string res;
		foreach (idx, v; values) {
			if (idx > 0)
				res ~= ".";
			res ~= to!string(v);
		}
		return "[path: " ~ res ~ "]";
	}
}

class Slice_Expression_Node : Expression_Node {
	Expression_Node start, end;

	this(Expression_Node start, Expression_Node end) {
		this.start = start;
	}
}

class Index_Expression_Node : Expression_Node {
	Expression_Node array, index;

	this(Expression_Node array, Expression_Node index) {
		this.array = array;
		this.index = index;
	}

	override string toString() {
		return to!string(array) ~ "[" ~ to!string(index) ~ "]";
	}
}

class Lambda_Node : Expression_Node {
	Function_Type_Node func_type;
	Block_Node block;

	this(Function_Type_Node func_type, Block_Node block) {
		this.func_type = func_type;
		this.block = block;
	}
}

class Block_Expression_Node : Expression_Node {
	Block_Node block;

	this(Block_Node block) {
		this.block = block;
	}

	override string toString() {
		return "eval ...";
	}
}

class Binary_Expression_Node : Expression_Node {
	Expression_Node left, right;
	Token operand;

	this(Expression_Node left, Token operator, Expression_Node right) {
		this.left = left;
		this.operand = operator;
		this.right = right;
	}

	override string toString() {
		return to!string(left) ~ operand.lexeme ~ to!string(right);
	}
}

class Unary_Expression_Node : Expression_Node {
	Token operand;
	Expression_Node value;

	this(Token operand, Expression_Node value) {
		this.operand = operand;
		this.value = value;
	}

	override string toString() {
		return operand.lexeme ~ to!string(value);
	}
}

class Paren_Expression_Node : Expression_Node {
	Expression_Node value;

	this(Expression_Node value) {
		this.value = value;
	}

	override string toString() {
		return "(" ~ to!string(value) ~ ")";
	}
}

// TYPE AST NODES

alias Generic_Set = Generic_Sigil[];

class Type_Node : Node {
	Generic_Set sigils;
}

class Primitive_Type_Node : Type_Node {
	Token type_name;

	this(Token type_name) {
		this.type_name = type_name;
	}

	override string toString() {
		return type_name.lexeme;
	}
}

// complex types

class Type_Path_Node : Type_Node {
	Token[] values;

	override string toString() {
		string res;
		foreach (i, v; values) {
			if (i > 0) res ~= '.';
			res ~= v.lexeme;
		}
		return res;
	}
}

// TODO i might remove this and replace
// it with some generic tuple type in the
// runtime/stdlib
class Tuple_Type_Node : Type_Node {
	Type_Node[] types;

	override string toString() {
		string res;
		foreach (i, v; types) {
			if (i > 0) res ~= ',';
			res ~= to!string(v);
		}
		return '(' ~ res ~ ')';
	}
}

class Mutable_Type_Node : Type_Node {
public:
	Type_Node base_type;

	this(Type_Node base_type) {
		this.base_type = base_type;
	}

	override string toString() {
		return "mut " ~ to!string(base_type);
	}
}

class Array_Type_Node : Type_Node {
public:
	Type_Node base_type;
	Expression_Node value;

	this(Type_Node base_type, Expression_Node value = null) {
		this.base_type = base_type;
		this.value = value;
	}

	override string toString() {
		return "[" ~ to!string(base_type) ~ ";" ~ to!string(value) ~ "]";
	}
}

class Slice_Type_Node : Type_Node {
public:
	Type_Node base_type;

	this(Type_Node base_type) {
		this.base_type = base_type;
	}

	override string toString() {
		return "&[" ~ to!string(base_type) ~ "]";
	}
}

class Pointer_Type_Node : Type_Node {
public:
	Type_Node base_type;

	this(Type_Node base_type) {
		this.base_type = base_type;
	}

	override string toString() {
		return "*" ~ to!string(base_type);
	}
}

class Union_Field : Node {
	Token name;
	Type_Node type;

	this(Token name, Type_Node type) {
		this.name = name;
		this.type = type;
	}
};

class Union_Type_Node : Type_Node {
public:
	Union_Field[] fields;

	void add_field(Token name, Type_Node type) {
		fields ~= new Union_Field(name, type);
	}
}

class Structure_Field : Node {
	Token name;
	Type_Node type;
	Expression_Node value;

	this(Token name, Type_Node type, Expression_Node value = null) {
		this.name = name;
		this.type = type;
		this.value = value;
		set_tok_info(name);
	}

	override string toString() {
		string val = "";
		if (value !is null) {
			val = "=" ~ to!string(value);
		}
		return name.lexeme ~ ":" ~ to!string(type) ~ val;
	}
};

class Structure_Type_Node : Type_Node {
public:
	Structure_Field[] fields;

	void add_field(Token name, Type_Node type, Expression_Node value = null) {
		fields ~= new Structure_Field(name, type, value);
	}

	override string toString() {
		string fields;
		foreach (i, f; fields) {
			if (i > 0) fields ~= ';';
			fields ~= to!string(f);
		}
		return "struct {" ~ fields ~ "}";
	}
}

class Function_Parameter : Node {
	bool mutable;
	Token twine;
	Type_Node type;

	this(bool mutable, Token twine, Type_Node type) {
		this.mutable = mutable;
		this.twine = twine;
		this.type = type;
	}

	override string toString() {
		return (mutable ? "mut" : "") ~ " " ~ twine.lexeme ~ " : " ~ to!string(type);
	}
}

class Function_Type_Node : Type_Node {
public:
	Type_Node return_type;
	Function_Parameter[] params;
	Function_Parameter recv;

	void set_recv(Token twine, Type_Node type, bool mutable = false) {
		recv = new Function_Parameter(mutable, twine, type);
	}

	void add_param(Token twine, Type_Node type, bool mutable = false) {
		params ~= new Function_Parameter(mutable, twine, type);
	}

	override string toString() {
		string stringified_params;
		foreach (i, p; params) {
			if (i > 0) stringified_params ~= ",";
			stringified_params ~= to!string(params);
		}
		return "fn(" ~ stringified_params ~ ")";
	}
}

class Trait_Attribute : Node {
	Token twine;
	Function_Type_Node type;

	this(Token twine, Function_Type_Node type) {
		this.twine = twine;
		this.type = type;
	}
}

class Trait_Type_Node : Type_Node {
public:
	Trait_Attribute[] attributes;

	void add_attrib(Token name, Function_Type_Node func_type_node) {
		attributes ~= new Trait_Attribute(name, func_type_node);
	}
}

class Tagged_Union_Field {
	Token identifier;

	// optional, restricted to
	// struct or tuple
	Type_Node type;

	this(Token identifier, Type_Node type) {
		this.identifier = identifier;
		this.type = type;
	}

	override string toString() {
		return to!string(identifier) ~ " " ~ to!string(type);
	}
}

class Tagged_Union_Type_Node : Type_Node {
public:
	Tagged_Union_Field[] fields;

	void add_field(Token identifier, Type_Node t = null) {
		fields ~= new Tagged_Union_Field(identifier, t);
	}

	override string toString() {
		string field_str;
		foreach (i, v; fields) {
			if (i > 0) {
				field_str ~= ",\n";
			}
			field_str ~= to!string(v);
		}
		return "enum { " ~ field_str ~ " }";
	}
}

// GENERIC STUFF

struct Generic_Sigil {
	Token name;
	Type_Path_Node[] restrictions;
}
