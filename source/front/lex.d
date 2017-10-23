module lex.lexer;

import std.functional; 
import std.stdio;
import std.array : replace;
import std.uni;
import std.conv;
import std.range.primitives;

import krug_module;
import compilation_phase;
import grammar;

static bool is_end_of_line(dchar c) {
	return c == '\r' || c == '\n' || c == '\u2028' || c == '\u2029';
}

class Lexer : Compilation_Phase {
	Source_File* curr_file;

	string input;
	uint position;

	uint row = 1, col = 1;

	this(ref Source_File file) {
		this.input = file.contents;
		this.curr_file = &file;
	}

	string get_name() {
		return "Lexical Analysis";
	}

	// TODO:
	string recognize_esc_seq() {
		string result;
		if (peek() == '\\') {
			result ~= consume();
			dchar esc_prefix = peek();
			switch (esc_prefix) {
			case '"':
			case '\'':
			case '\\':
			case 'n':
			case 't':
			case 'b':
			case 'r':	
				result ~= consume();
				break;
			case 'x': // hex
				break;
			case 'o': // octal
				break;
			case 'u': // unicode, 4 hex digits
				break;	
			case 'U': // unicode, 8 hex digits
				break;
			default: 
				// 3 diigts?
				break;
			}
		}
		return result;
	}

	Token recognize_str() {
		string lexeme = to!string(expect('"'));
		while (has_next()) {
			if (peek() == '\\') {
				lexeme ~= recognize_esc_seq();
			}

			if (peek() == '"') {
				break;
			}
			lexeme ~= consume();
		}
		lexeme ~= expect('"');
		return new Token(lexeme, Token_Type.String);
	}

	Token recognize_raw_str() {
		// TODO:
		return new Token("", Token_Type.String); 
	}

	Token recognize_char() {
		string buffer = to!string(expect('\''));
		if (peek() == '\\') {
			buffer ~= recognize_esc_seq();
		}
		else {
			buffer ~= consume();
		}
		buffer ~= expect('\'');
		return new Token(buffer, Token_Type.Rune);
	}

	Token recognize_num() {
		string sign;
		if (peek() == '-' || peek() == '+') {
			sign ~= consume();
		}

		switch (peek(1)) {
		case 'x': case 'X':
			string prefix = sign ~ to!string(consume()) ~ to!string(consume());
			return new Token(prefix ~ consume_while(is_hexadecimal), Token_Type.Integer_Literal);
		case 'o': case 'O':
			string prefix = sign ~ to!string(consume()) ~ to!string(consume());
			return new Token(prefix ~ consume_while(is_octal), Token_Type.Integer_Literal);
		case 'b': case 'B':
			string prefix = sign ~ to!string(consume()) ~ to!string(consume());
			return new Token(prefix ~ consume_while(is_binary), Token_Type.Integer_Literal);
		case 'd': case 'D':
			string prefix = sign ~ to!string(consume()) ~ to!string(consume());
			return new Token(prefix ~ consume_while(is_decimal), Token_Type.Integer_Literal);
		default:
			if (isAlpha(peek(1))) {
				writeln("TODO: o fuck\n");
			}
		}

		Token tok = new Token(consume_while(is_decimal), Token_Type.Integer_Literal);
		tok.lexeme = sign ~ tok.lexeme;

		if (peek() == '.' && (peek(1) == 'e' || peek(1) == 'E') || is_decimal(peek(1))) {
			consume();
			string precision = "." ~ consume_while(is_decimal);

			if (peek() == 'E' || peek() == 'e') {
				precision ~= to!string(consume());
				if (peek() == '+' || peek() == '-') {
					precision ~= to!string(consume());
				}
				precision ~= consume_while(is_decimal);
			}

			tok.lexeme ~= precision;
			tok.type = Token_Type.Floating_Point_Literal;
		}

		return tok;
	}

	void eat_comment() {
		consume_while(function (dchar c) => !is_end_of_line(c));
	}

	// eats a multi line comments, this also
	// handles nested multi line comments too
	void eat_multi_comment() {
		// for tracking the depth of the comment
		int num_comments = 0;
		int[] last_open_comment_indices;

		do {
			if (peek() == '/' && peek(1) == '*') {
				last_open_comment_indices ~= position;
				consume(); consume();
				num_comments++;
			}
			else if (peek() == '*' && peek(1) == '/') {
				last_open_comment_indices.popBack();
				consume(); consume();
				num_comments--;
			}
			consume();
		}
		while (has_next() && num_comments > 0);

		// unclosed comments probably
		if (num_comments > 0 || last_open_comment_indices.length > 0) {
			string error_msg;
			while (!last_open_comment_indices.length > 0) {
				int index = last_open_comment_indices.back;
				last_open_comment_indices.popBack();
				error_msg ~= "comment unclosed: at " ~ to!string(index) ~ ".\n";
			}
			writeln("todo: better error\n", error_msg);
		}
	}

	Token recognize_identifier(bool keyword_check) {
		string value = consume_while(is_identifier);
		auto type = Token_Type.Identifier;
		if (keyword_check && value in KEYWORDS) {
			type = Token_Type.Keyword;
		}
		return new Token(value, type); 
	}

	Token recognize_sym() {
		string val = to!string(consume());	
		if ((val ~ to!string(peek())) in SYMBOLS) {
			val ~= consume();
		}
		return new Token(val, Token_Type.Symbol);
	}

	Token[] tokenize() {
		Token[] tok_stream;
		
		ulong last_line = 0, pad = 0;
		while (has_next()) {
			last_line = row;

			// eat all the junk stuff, 
			// below 32 on the ascii table.
			string junk = consume_while((dchar c) => c <= ' ');
			junk = junk.replace("\t", "");
			junk = junk.replace("\r", "");
			junk = junk.replace("\n", "");

			if (row == last_line) {
				pad = pad + junk.length;
			} else {
				pad = 0;
			}

			dchar curr = peek();
			if (curr == '\0') {
				break;
			}

			Token recognized_token;
			Location start_loc = capture_location();
			
			// check if we have a special-string, in
			// this case a c-style string which is denoted
			// as c"foo bar baz".
			if (curr == 'c' && peek(1) == '"') {
				dchar prefix = consume();
			}
			// identifier, cannot start with underscore
			else if (isAlpha(curr)) {
				recognized_token = recognize_identifier(true);
			}
			// discard?
			else if (curr == '_') {
				recognized_token = new Token(to!string(consume()), Token_Type.Identifier);
			}
			// keyword as identifier, e.g. $type, $struct
			else if (curr == '$') {
				consume();
				recognized_token = recognize_identifier(false);
			}
			// single line comment
			else if (curr == '/' && peek(1) == '/') {
				eat_comment();
			}
			// multi line comment
			else if (curr == '/' && peek(1) == '*') {
				eat_multi_comment();
			}
			// raw string literal
			else if (curr == '`') {
				recognized_token = recognize_raw_str();
			}
			else if (isNumber(peek())) {
				recognized_token = recognize_num();
			}
			// (-|+)digit or just digit
			else if ((curr == '+' || curr == '-') && isNumber(peek(1))) {
				recognized_token = recognize_num();
			}
			else if (to!string(curr) in SYMBOLS 
					|| (to!string(curr) ~ to!string(peek(1))) in SYMBOLS) {
				recognized_token = recognize_sym();
			}
			else if (curr == '"') {
				recognized_token = recognize_str();
			}
			else if (curr == '\'') {
				recognized_token = recognize_char();
			}
			else {
				writeln("what is " ~ to!string(peek()));
			}

			if (recognized_token !is null) {			
				start_loc.col -= pad;
				Location end = capture_location();
				end.col -= pad;
				recognized_token.position = new Span(start_loc, end, tok_stream.length - 1);
                recognized_token.parent = curr_file;
				tok_stream ~= recognized_token;
			}
		}
		return tok_stream;
	}

	bool has_next() {
		return position < input.length;
	}

	dchar peek(int offs = 0) {
		if (!has_next()) {
			return '\0';
		}
		if (position + offs >= input.length) {
			return '\0';
		}
		return input[position + offs];
	}

	Location capture_location() {
		return new Location(position, row, col);
	}

	string consume_while(bool function(dchar) pred) {
		string result; // TODO is there a string builder thing?
		while (has_next()) {
			if (!pred(peek())) {
				break;
			}
			result ~= consume();
		}
		return result;
	}

	dchar consume() {
		dchar curr = peek();
		if (curr == '\n') {
			row++;
			col = 1;
		}
		col++;
		position++;
		return curr;
	}

	dchar expect(dchar c) {
		if (has_next() && peek() == c) {
			return consume();
		}

		if (!has_next()) {
			assert(0 && "eof");
		}

		assert(0 && "expected!");
	}

	dchar expect(bool delegate(dchar) pred, string err) {
		if (has_next() && pred(peek())) {
			return consume();
		}

		if (!has_next()) {
			assert(0 && "eof");
		}

		assert(0 && "expected");
	}
}