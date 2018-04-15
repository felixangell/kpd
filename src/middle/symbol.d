module sema.symbol;

import std.conv;

import logger;
import ast;
import sema.infer : Type_Environment;
import tok;

class Symbol_Value {
	ast.Node reference;
	Token tok;
	string name;
	bool mutable;

	this(ast.Node reference, Token tok, bool mutable) {
		this(reference, tok.lexeme, mutable);
		this.tok = tok;
		this.mutable = mutable;
	}

	this(ast.Node reference, string name, bool mutable) {
		this.reference = reference;
		this.name = name;
		this.mutable = mutable;
	}

	this() {
		// debug only
		this.name = "__anonymous_sym_table";
	}

	Token_Info get_tok_info() {
		return reference.get_tok_info();
	}

	override string toString() const {
		if (reference is null) {
			return name;
		}
		return name ~ " val " ~ to!string(typeid(reference));
	}
}

import std.random;
auto rnd = Random(0xff00ff);

class Symbol_Table : Symbol_Value {
	Symbol_Table outer;
	Symbol_Value[string] symbols;

	uint id;
	Type_Environment env;

	// FIXME symbol tables are
	// probably? mutable.

	this(ast.Node reference, Token tok) {
		super(reference, tok.lexeme, true);
	}

	this(ast.Node reference, string name) {
		super(reference, name, true);
	}

	this(Symbol_Table outer = null) {
		super();

		debug {
			this.id = uniform!uint(rnd);
		}
		else {
			this.id = outer is null ? 0 : outer.id + 1;
		}

		this.outer = outer;

		if (outer is null) {
			env = new Type_Environment;
		}
		else {
			env = new Type_Environment(outer.env);
		}
	}

	void dump_values() {
		logger.verbose("symbol_table_" ~ to!string(id) ~ ":");
		foreach (v; symbols.byKeyValue()) {
			logger.verbose("  > ", v.key);
		}
		logger.verbose(".");
	}

	// registers the given symbol, if the
	// symbol already exists it will be
	// returned from the symbol table in the scope.
	Symbol_Value register_sym(string name, Symbol_Value s) {
		logger.verbose("Registering symbol ", name, " // ", to!string(s), " STAB#", to!string(this.id));
		if (name in symbols) {
			return symbols[name];
		}
		symbols[name] = s;
		return null;
	}

	Symbol_Value register_sym(Symbol_Value s) {
		return register_sym(s.name, s);
	}

	override string toString() const {
		if (reference is null) {
			return name ~ " (table with " ~ to!string(symbols.length) ~ " entries) ";
		}
		return name ~ " (table with " ~ to!string(symbols.length) ~ " entries) " ~ to!string(typeid(reference));
	}
}

// is this even necessary?
class Symbol : Symbol_Value {
	// bog standard entry really.
	this(ast.Node reference, Token tok, bool mutable) {
		super(reference, tok, mutable);
	}

	this(ast.Node reference, string name, bool mutable) {
		super(reference, name, mutable);
	}

	override string toString() const {
		if (reference is null) {
			return name;
		}
		return name ~ " -> " ~ to!string(typeid(reference));
	}
}
