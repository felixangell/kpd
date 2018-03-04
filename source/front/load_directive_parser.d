module parse.load_directive_parser;

import std.stdio;
import std.conv;
import std.algorithm.comparison : equal;
import std.typecons;

import krug_module;

// a very simple specialized parser that parses
// the given token streams for load directives 
// only!
struct Load_Directive_Parser {
	Token[] toks;
	uint pos;

	this(ref Token[] toks) {
		this.toks = toks;
		this.pos = 0;
	}

	Token consume() {
		return toks[pos++];
	}

	Token expect(string lexeme) {
		Token t = peek();
		if (t.lexeme.equal(lexeme)) {
			return consume();
		}

		writeln("oh dear! " ~ lexeme ~ " vs. `" ~ t.lexeme ~ "` for " ~ to!string(
				t));
		return null;
	}

	Token expect(Token_Type type) {
		Token t = consume();
		if (t.type == type) {
			return t;
		}

		writeln("oh dear, type mismatch! " ~ to!string(
				type) ~ " vs " ~ to!string(t.type) ~ " for " ~ to!string(t));
		assert(0);
	}

	bool has_next() {
		return pos < toks.length;
	}

	Token peek(int offs = 0) {
		return toks[pos + offs];
	}
}

alias Load_Directive = Tuple!(Token, Token[]);

// parses the given token stream
Load_Directive[] collect_deps(ref Token[] toks) {
	Load_Directive[] deps;

	// this is very simple we pass through all of the tokens
	// parsing only very specific directives:
	Load_Directive_Parser parser = Load_Directive_Parser(toks);
	while (parser.has_next()) {

		// we basically skip all tokens till 
		// we come across something with a #
		Token curr = parser.consume();
		if (!curr.cmp("#")) {
			continue;
		}

		// we dont have to expect a #
		// because curr has already consumed it

		Token directive_name = parser.expect(Token_Type.Identifier);
		if (!directive_name.cmp("load")) {
			continue;
		}

		// the module name, this could be a folder
		// or a file (submodule)?
		Token module_name = parser.expect(Token_Type.Identifier);

		// there are allowed to be no sub modules
		Token[] sub_mods;

		// TODO: clean this up!

		// we're accessing a sub-module
		if (parser.has_next() && parser.peek().cmp("::")) {
			parser.consume();

			// parse a submodule list
			if (parser.has_next() && parser.peek().cmp("{")) {
				parser.consume();

				while (parser.has_next() && !parser.peek().cmp("}")) {
					sub_mods ~= parser.expect(Token_Type.Identifier);

					// TODO: allow trailing commas?
					//  TODO: enforce comma seperation here
					// this is basically optional.
					if (parser.peek().cmp(",")) {
						parser.consume();
					}
				}
				parser.expect("}");
			} else {
				sub_mods ~= parser.expect(Token_Type.Identifier);
			}
		}

		deps ~= Load_Directive(module_name, sub_mods);
	}

	return deps;
}
