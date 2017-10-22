import std.string;
import std.uni;

import ds;

static Hash_Set!string EXPRESSION_KEYWORDS;
static Hash_Set!string BINARY_OPERATORS;
static Hash_Set!string RELATIONAL_OPERATORS;
static Hash_Set!string ADD_OPERATORS;
static Hash_Set!string MUL_OPERATORS;
static Hash_Set!string UNARY_OPERATORS;
static Hash_Set!string SYMBOLS;
static Hash_Set!string KEYWORDS;

static uint[string] OPERATOR_PRECEDENCE;

static this() {
	KEYWORDS = new Hash_Set!string(
		"fn", "let", "type",
		"if", "else", "loop", "while", "match", "for",
		"return", "break", "next",
		"as", "mut", "default", "eval",
		"length", "size_of", "type_of", "len",
		"struct", "trait", "union", "enum",
		"defer", "false", "true", "bool", "rune", "yield",
		"self", "clang",
	);

	OPERATOR_PRECEDENCE["as"] = 6;
	
	OPERATOR_PRECEDENCE["*"] = 5;
	OPERATOR_PRECEDENCE["/"] = 5;
	OPERATOR_PRECEDENCE["%"] = 5;
	OPERATOR_PRECEDENCE["<<"] = 5;
	OPERATOR_PRECEDENCE[">>"] = 5;
	OPERATOR_PRECEDENCE["&"] = 5;

	OPERATOR_PRECEDENCE["+"] = 4;
	OPERATOR_PRECEDENCE["-"] = 4;
	OPERATOR_PRECEDENCE["|"] = 4;
	OPERATOR_PRECEDENCE["^"] = 4;

	OPERATOR_PRECEDENCE["size_of"] = 3;
	OPERATOR_PRECEDENCE["type_of"] = 3;
	OPERATOR_PRECEDENCE["len_of"] = 3;
	OPERATOR_PRECEDENCE["=="] = 3;
	OPERATOR_PRECEDENCE["!="] = 3;
	OPERATOR_PRECEDENCE["<"] = 3;
	OPERATOR_PRECEDENCE["<="] = 3;
	OPERATOR_PRECEDENCE[">"] = 3;
	OPERATOR_PRECEDENCE[">="] = 3;

	OPERATOR_PRECEDENCE["&&"] = 2;

	OPERATOR_PRECEDENCE["+="] = 1;
	OPERATOR_PRECEDENCE["-="] = 1;
	OPERATOR_PRECEDENCE["/="] = 1;
	OPERATOR_PRECEDENCE["*="] = 1;
	OPERATOR_PRECEDENCE["||"] = 1;
	OPERATOR_PRECEDENCE["="] = 1;
	OPERATOR_PRECEDENCE["..."] = 1;
	OPERATOR_PRECEDENCE[".."] = 1;

	EXPRESSION_KEYWORDS = new Hash_Set!string(
		"size_of", "type_of", "len_of",
		"true", "false",
	);

	BINARY_OPERATORS = new Hash_Set!string(
		"||", "&&", "=", "as", "::", "..", "...",
		"+=", "-=", "/=", "*=",
	);

	RELATIONAL_OPERATORS = new Hash_Set!string(
		"==", "!=", "<", ">", "<=", ">="
	);
	
	ADD_OPERATORS = new Hash_Set!string(
		"+", "-", "|", "^"
	);
	
	MUL_OPERATORS = new Hash_Set!string(
		"*", "/", "%", "<<", ">>", "&"
	);
	
	UNARY_OPERATORS = new Hash_Set!string(
		"+", "-", "!", "^", "@", "&"
	);

	SYMBOLS = new Hash_Set!string(
		"::" , "->" , "@"  ,  "=>" , "<-" , "!=" , 
		"==" ,"<=" , ">=" , "<<" , ">>" , ".." , 
		"&&" , "||" , "as" ,"+=" , "-=" , "/=" , 
		"*=" ,"%" ,  "=" ,  "*" ,  ":" , "^" , 
		"+" , "-" , "!" , "#" , "/" , "," , ";" , 
		"." ,"[" ,  "]" ,  "{" ,  "}" , "(" , ")" ,
		"<", ">",
	);
}

static bool is_binary_op(string s) {
	return s in BINARY_OPERATORS || is_rel_op(s) || is_add_op(s) || is_mul_op(s);
}

static bool is_rel_op(string s) {
	return s in RELATIONAL_OPERATORS;
}

static bool is_add_op(string s) {
	return s in ADD_OPERATORS;
}

static bool is_mul_op(string s) {
	return s in MUL_OPERATORS;
}

static bool is_unary_op(string s) {
	return s in UNARY_OPERATORS;
}

auto is_identifier = (dchar c) => isAlpha(c) || isNumber(c) || c == '_';
auto is_decimal = (dchar c) => (c >= '0' && c <= '9') || c == '_';
auto is_hexadecimal = (dchar c) => isNumber(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F') || c == '_';
auto is_octal = (dchar c) => (c >= '0' && c <= '7') || c == '_';
auto is_binary = (dchar c) => c == '0' || c == '1' || c == '_';

static bool str_is_identifier(string s) {
	if (s.startsWith("_") || isNumber(s[0])) {
		return false;
	}

	foreach (dchar character; s) {
		if (!is_identifier(character)) {
			return false;
		}
	}
	return true;
}