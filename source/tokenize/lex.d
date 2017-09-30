module tokenize;

import std.functional; 
import std.stdio;
import std.array : replace;
import std.uni;
import std.conv;

import krug_module;
import compilation_phase;
import grammar;

static bool is_end_of_line(dchar c) {
	return c == '\r' || c == '\n' || c == '\u2028' || c == '\u2029';
}

class Lexer : Compilation_Phase {
	string input;
	uint position;

	uint row = 1, col = 1;

	this(string input) {
		this.input = input;
	}

	string get_name() {
		return "Lexical Analysis";
	}

	string recognize_esc_seq() {
		string result;
		if (peek() == '\\') {
			result ~= consume();
			char esc_prefix = peek();
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
		string lexeme = expect('"');
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
		return Token(lexeme, Token_Type.String);
	}

	Token recognize_raw_str() {

	}

	Token recognize_char() {
		string buffer = expect('\'');
		if (peek() == '\\') {
			buffer ~= recognize_esc_seq();
		}
		else {
			buffer ~= consume();
		}
		buffer ~= expect('\'');
		return Token(buffer, Token_Type.Character);
	}

	Token recognize_num() {
		string sign;
		if (peek() = '-' || peek() == '+') {
			sign = consume();
		}

		switch (peek(1)) {
		case 'x': case 'X':
			string prefix = sign + consume() + consume();
			break;
		case 'o': case 'O':
			break;
		case 'b': case 'B':
			break;
		case 'd': case 'D':
			break;
		default:

			break;	
		}
	}

	void eat_comment() {
		consume_while(function (dchar c) => !is_end_of_line(c));
	}

	Token recognize_identifier(bool keyword_check) {
		string value = consume_while(is_identifier);
		auto type = Token_Type.Identifier;
		if (keyword_check && value in KEYWORDS) {
			type = Token_Type.Keyword;
		}
		return Token(value, type); 
	}

	Token[] tokenize() {
		Token[] tok_stream;
		
		uint last_line = 0, pad = 0;
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

			char curr = peek();
			if (curr == '\0') {
				break;
			}

			Token recognized_token;
			Location start_loc = capture_location();
			
			// check if we have a special-string, in
			// this case a c-style string which is denoted
			// as c"foo bar baz".
			if (curr == 'c' && peek(1) == '"') {
				char prefix = consume();
			}
			// identifier, cannot start with underscore
			else if (isAlpha(curr)) {
				recognized_token = recognize_identifier(true);
			}
			// discard?
			else if (curr == '_') {
				recognized_token = Token(to!string(consume()), Token_Type.Identifier);
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

			}
			// raw string literal
			else if (curr == '`') {
				recognized_token = recognize_raw_str();
			}
			// (-|+)digit or just digit
			else if (((curr == '+') || (curr == '-') && isNumber(peek(1))) || isNumber(peek())) {
				recognized_token = recognize_num();
			}
			else if (curr == '"') {
				recognized_token = recognize_str();
			}
			else if (curr == '\'') {
				recognized_token = recognize_char();
			}
		}
		return tok_stream;
	}

	bool has_next() {
		return position < input.length;
	}

	char peek(int offs = 0) {
		if (!has_next()) {
			return '\0';
		}
		if (position + offs >= input.length) {
			return '\0';
		}
		return input[position + offs];
	}

	Location capture_location() {
		return Location(position, row, col);
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

	char consume() {
		char curr = peek();
		if (curr == '\n') {
			row++;
			col = 1;
		}
		col++;
		position++;
		return curr;
	}

	char expect(bool delegate(char) pred, string err) {
		if (!has_next() && pred(peek())) {
			return consume();
		}

		if (!has_next()) {
			assert(0 && "eof");
		}

		assert(0 && "expected");
	}
}