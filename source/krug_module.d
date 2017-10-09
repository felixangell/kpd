module krug_module;

import std.file;
import std.algorithm.searching : startsWith;
import std.algorithm.comparison : equal;
import std.conv;

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

class Location {
	uint idx, row, col;

	this(uint idx, uint row, uint col) {
		this.idx = idx;
		this.row = row;
		this.col = col;
	}

	override string toString() const {
		return to!string(row) ~ ":" ~ to!string(col);
	}
};

class Span {
	Location start, end;
	uint index;

	this(Location start, Location end, uint index) {
		this.start = start;
		this.end = end;
		this.index = index;
	}

	override string toString() const { 
		return to!string(start) ~ " - " ~ to!string(end);
	}
};

class Token {
	string lexeme;
	Token_Type type;
	Span position;

	this(string lexeme, Token_Type type) {
		this.lexeme = lexeme;
		this.type = type;
	}

	bool cmp(string lexeme) {
		return this.lexeme.equal(lexeme);
	}

	bool cmp(Token_Type type) {
		return this.type == type;
	}

	override string toString() const {
		return lexeme ~ ", " ~ to!string(type) ~ " @ " ~ to!string(position);
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