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
	Keyword,
	EOF,
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
	ulong index;

	this(Location start, Location end, ulong index) {
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

class Source_File {
	string path;
	string contents;

	this(string path) {
		this.path = path;
		this.contents = readText(path);
	}
}