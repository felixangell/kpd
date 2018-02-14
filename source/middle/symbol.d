module sema.symbol;

import std.conv;

import ast;
import sema.type;
import krug_module : Token;

class Symbol {
	ast.Node reference;

	Token tok;
	string name;
	Type type;

	this(ast.Node reference, Token tok) {
	    this(reference, tok.lexeme);
	    this.tok = tok;
	}

	this(ast.Node reference, string name) {
        this.reference = reference;
        this.name = name;
	}

	override string toString() const {
	    return name ~ " -> " ~ to!string(typeid(reference));
	}
}