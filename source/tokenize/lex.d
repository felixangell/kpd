module tokenize;

import std.functional; 
import std.stdio;
import std.array : replace;

import krug_module;
import compilation_phase;
import grammar;

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

	void recognize_identifier(bool keyword_check) {
		string value = consume_while(is_identifier);
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