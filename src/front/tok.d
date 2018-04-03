module tok;

import std.conv : to;
import std.algorithm.comparison : equal;

import krug_module : Source_File;

enum Token_Type {
	Identifier,
	Floating_Point_Literal,
	Integer_Literal,
	String,
	CString,
	Rune,
	Symbol,
	Discard,
	Keyword,
	EOF,
};

interface Token_Info {
	// get's the _root_ token
	Token get_tok();
}

class Token {
	Source_File parent;
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

class Absolute_Token : Token_Info {
	Token tok;

	this(Token tok) {
		this.tok = tok;
	}

	Token get_tok() {
		return tok;
	}
}

class Token_Span : Token_Info {
	Token start, end;

	this(Token start, Token end) {
		this.start = start;
		this.end = end;
	}

	Token get_tok() {
		return start;
	}
}

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