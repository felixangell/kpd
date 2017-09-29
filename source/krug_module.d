module krug_module;

import std.file;
import std.algorithm.searching : startsWith;

import tokenize;

enum Token_Type {
	Identifier,
	Floating_Point_Literal,
	Integer_Literal,
	String,
	Rune,
	Symbol,
	Discard,
	Keyword
};

struct Location {
	uint idx, start, end;

	this(uint idx, uint start, uint end) {
		this.idx = idx;
		this.start = start;
		this.end = end;
	}
};

struct Span {
	Location start, end;

	this(Location start, Location end) {
		this.start = start;
		this.end = end;
	}
};

struct Token {
	string lexeme;
	Token_Type type;
	Span position;

	this(string lexeme, Token_Type type) {
		this.lexeme = lexeme;
		this.type = type;
	}
}

struct Krug_Module {
	string path;
	string contents;

	this(string path) {
		this.path = path;
		this.contents = readText(path);
	}
}