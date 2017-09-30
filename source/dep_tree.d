module dep_tree;

import std.stdio;
import std.conv;

import krug_module;

struct Dependency_Tree_Builder {
	Token[] toks;
	uint pos;

	this(ref Token[] toks) {
		this.toks = toks;
		this.pos = 0;
	}

	Token consume() {
		return toks[pos++];
	}

	Token expect(Token_Type type) {
		Token t = consume();
		assert(t.type == type);
		return t;
	}

	Token peek(int offs = 0) {
		return toks[pos + offs];
	}
}

// parses the given tokens into
// a dependency tree
void parse_dep_tree(ref Token[] toks) {
	writeln("Parsing dependency tree!");

	// this is very simple we pass through all of the tokens
	// parsing only very specific directives:
	Dependency_Tree_Builder builder = Dependency_Tree_Builder(toks);
	while (builder.pos < toks.length) {
		Token curr = builder.peek();
		if (curr.lexeme != "#") {
			builder.consume();
			continue;
		}

		builder.consume(); // #
		Token directive_name = builder.expect(Token_Type.Identifier);
		if (directive_name.lexeme != "load") {
			continue;
		}

		// we have a directive, and it SHOULD be for a dependency load
		// now we have to parse it.
		writeln(builder.peek());
	}
}