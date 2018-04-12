module tok;

import std.conv : to;
import std.algorithm.comparison : equal, min, max;
import std.string;

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

	// convert the token info to 
	// a printable string
	string print_tok();
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

	string print_tok() {
		return tok.lexeme;
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

	string print_tok() {
		Source_File file = start.parent;
		const size_t st_index = start.position.start.idx;
		const size_t en_index = end.position.end.idx;

		// capture to the previous line
		// of the token.
		long token_start = lastIndexOf(file.contents, '\n', cast(size_t) st_index);
		token_start = max(0, token_start);

		// capture up to the next newline
		auto line_end_index = indexOf(file.contents, '\n', cast(size_t) en_index);
		line_end_index = max(0, line_end_index);

		if (line_end_index < token_start) {
			line_end_index = file.contents.length;
		}

		return file.contents[token_start .. line_end_index].stripLeft();
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