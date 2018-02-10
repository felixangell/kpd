// scope is a keyword so we'll dump it in
// a module called range for now
module sema.range;

import std.conv;

import ast;
import err_logger;
import krug_module : Token;
import sema.infer : Type_Environment;
import sema.type;
import sema.symbol;

class Scope {
	uint id;
	Scope outer;
	Symbol[string] symbols;
	Type_Environment env;

	this() {
		this(null);
	}

	this(Scope outer) {
		this.outer = outer;
		this.id = outer is null ? 0 : (outer.id + 1);
		env = outer is null ? new Type_Environment() : new Type_Environment(outer.env);
	}

	Symbol lookup_sym(string name) {
		for (Scope s = this; s !is null; s = s.outer) {
			if (name in s.symbols) {
				return s.symbols[name];
			}
		}
		return null;
	}

	// registers the given symbol, if the
	// symbol already exists it will be
	// returned from the symbol table in the scope.
	Symbol register_sym(Symbol s) {
		err_logger.Verbose("Registering symbol " ~ to!string(s));
		if (s.name in symbols) {
			return symbols[s.name];
		}
		symbols[s.name] = s;
		return null;
	}
}