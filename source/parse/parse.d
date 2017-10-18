module parse;

import krug_module;

struct Parser {
	Token[] toks;
	uint pos = 0;

	this(Token[] toks) {
		this.toks = toks;
		while (has_next()) {
			Token tok = next();
			
		}
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