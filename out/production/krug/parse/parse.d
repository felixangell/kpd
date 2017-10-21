module parse.parser;

import krug_module;
import ast;

struct Parser {
	Token[] toks;
	uint pos = 0;

	this(Token[] toks) {
		this.toks = toks;
	}

	ast.Node[] parse() {
		ast.Node[] nodes;
		while (has_next()) {
			ast.Node node = parseNode();
			if (node !is null) {
				nodes ~= node;
			}
		}
		return nodes;
	}

	ast.Node parseNode() {
		return null;
	}

	Token next(uint offs = 0) {
		return toks[pos + offs];
	}

	Token consume() {
		return toks[pos++];
	}

	bool has_next() {
		return pos < toks.length;
	}
}