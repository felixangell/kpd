module dep_tree;

import std.stdio;
import std.conv;
import std.algorithm.comparison : equal;

import krug_module;

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

		writeln("oh dear! " ~ lexeme ~ " vs. `" ~ t.lexeme ~ "` for " ~ to!string(t));
		return null;
	}

	Token expect(Token_Type type) {
		Token t = consume();
		if (t.type == type) {
			return t;
		}
		
		writeln("oh dear, type mismatch! " ~ to!string(type) ~ " vs " ~ to!string(t.type) ~ " for " ~ to!string(t));
		assert(0);
	}

	Token peek(int offs = 0) {
		return toks[pos + offs];
	}
}

class Dependency {
	Token module_name;
	Token[] sub_mods;

	this(Token module_name, Token[] sub_mods) {
		this.module_name = module_name;
		this.sub_mods = sub_mods;
	}

	override string toString() const {
		string sm_str;
		
		int idx = 0;
		foreach (submod; sub_mods) {
			if (idx > 0) sm_str ~= ",";
			sm_str ~= submod.lexeme;
			idx++;
		}

		return module_name.lexeme ~ (sub_mods.length > 0 ? " -> " ~ sm_str : "");
	}
}

// parses the given tokens into
// a dependency tree
Dependency[] parse_dep_tree(ref Token[] toks) {
	writeln("Parsing dependency tree!");

	Dependency[] deps;

	// this is very simple we pass through all of the tokens
	// parsing only very specific directives:
	Load_Directive_Parser parser = Load_Directive_Parser(toks);
	while (parser.pos < toks.length) {
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
		Token[] sub_mods;

		// we're accessing a sub-module
		if (parser.peek().cmp("::")) {
			parser.consume();

			// parse a submodule list
			if (parser.peek().cmp("{")) {
				parser.consume();

				while (!parser.peek().cmp("}")) {
					sub_mods ~= parser.expect(Token_Type.Identifier);

					// TODO: allow trailing commas?
					//  TODO: enforce comma seperation here
					// this is basically optional.
					if (parser.peek().cmp(",")) {
						parser.consume();
					}
				}
				parser.expect("}");
			}
			else {
				sub_mods ~= parser.expect(Token_Type.Identifier);
			}
		}

		deps ~= new Dependency(module_name, sub_mods);
	}

	return deps;
}