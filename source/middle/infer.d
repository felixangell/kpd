module sema.infer;

import std.conv;
import std.stdio;
import std.algorithm : cmp;

import diag.engine;
import compiler_error;
import logger;
import sema.type;
import ast;
import colour;

// type environment contains all of the types that have
// been registered, this works _alongside_ the scope though
// it could be embedded into the scope.
//
// basically we have the top most type environment which
// contains all of our primitives
// whenever we enter a new scope and we create new types
// we register them, then we look up types in the type environment
// working our way outwards, 
//
// though perhaps an optimisation could
// be to copy all of the primitive types into any
// new child scopes otherwise we will have to search N
// layers outwards to get something as simple as a boolean
// and N could be a big number!
class Type_Environment {
	Type_Environment parent;

	this(Type_Environment parent) {
		this.parent = parent;

		// an optimisation.. we store all of the 
		// common primitives in every new Type_Environment
		// (we could also copy) so that we dont have
		// to search N layers outwards
		//
		// this is because N could be 284592843 (though... unrealistic)
		// and we don't want to have to do 284592843 calls to get
		// a boolean type!
		register_type("true", prim_type("bool"));
		register_type("false", prim_type("bool"));
	}

	this() {
		this(null);
	}

	Type[string] data;

	Type lookup_type(string name) {
		for (Type_Environment e = this; e !is null; e = e.parent) {
			if (name in e.data) {
				return e.data[name];
			}
		}

		return null;
	}

	// for example we could register that
	// true -> bool
	// false -> bool
	// or add -> [int, int] : int
	void register_type(string key, Type t) {
		logger.Verbose("Registering type ", key, " : ", to!string(t));
		assert(key !in data);
		data[key] = t;
	}
}

// t member of types?
bool occurs_in(Type t, Type[] types) {
	foreach (type; types) {
		if (occurs_in_type(t, type)) {
			return true;
		}
	}
	return false;
}

Type fresh(Type t, Type_Variable[string] generics) {
	Type_Variable[string] mappings;

	Type fresh_type(Type type, Type_Variable[string] generics) {
		auto pt = prune(type);
		if (auto var = cast(Type_Variable) pt) {
			if (var.get_name() in generics) {
				if (var.get_name() !in mappings) {
					auto new_type_var = new Type_Variable();
					mappings[new_type_var.get_name()] = new_type_var;
				}
				return mappings[var.get_name()];
			}
			return var;
		}
		else if (auto op = cast(Type_Operator) pt) {
			Type[] types;
			types.length = op.types.length;

			foreach (i, typ; op.types) {
				types[i] = fresh_type(typ, generics);
			}
			return new Type_Operator(op.get_name(), types);
		}
		else if (auto fn = cast(Function) pt) {
			Type[] types;
			types.length = fn.types.length;

			foreach (i, typ; fn.types) {
				types[i] = fresh_type(typ, generics);
			}

			return new Function(fresh_type(fn.ret, generics), types);
		}

		logger.Fatal("bad type!");
		assert(0);
	}

	return fresh_type(t, generics);
}

void unify(Type a, Type b) {
	auto pa = prune(a);
	auto pb = prune(b);

	if (auto var = cast(Type_Variable) pa) {
		if (var != pb) {
			var.instance = pb;
		}
	}
	else if (auto opa = cast(Type_Operator) pa) {
		if (auto var = cast(Type_Variable) pb) {
			unify(var, opa);
		}
		else if (auto opb = cast(Type_Operator) pb) {
			if (cmp(opa.name, opb.name) || opa.types.length != opb.types.length) {
				writeln("Type mismatch between types ", to!string(a), " and ", to!string(b));
			}

			foreach (idx, t; opa.types) {
				unify(t, opb.types[idx]);
			}
		}
	}
}

Type prune(Type t) {
	if (auto var = cast(Type_Variable) t) {
		if (var.instance !is null) {
			return var.instance;
		}
	}
	return t;
}

bool occurs_in_type(Type a, Type b) {
	auto pb = prune(b);
	if (pb == a) {
		return true;
	}

	if (auto op = cast(Type_Operator) pb) {
		return occurs_in(a, op.types);
	}
	return false;
}

Type_Node resolve(Type_Node old, Type resolved) {
	return new Resolved_Type(old, resolved);
}

struct Type_Inferrer {
	Type_Environment e;

	Type get_type(string name, Type_Variable[string] generics) {
		if (name in e.data) {
			logger.Verbose("Found '", name, "', type is ", to!string(e.data[name]));
			return fresh(e.data[name], generics);
		}

		logger.Error("Couldn't find type '", name, "' in environment:");

		foreach (entry; e.data.byKeyValue()) {
			logger.Verbose(entry.key, " is ", to!string(entry.value));
		}
		
		assert(0);
	}

	Type analyze_primitive(ast.Primitive_Type_Node node, Type_Variable[string] generics) {
		auto type_name = node.type_name.lexeme;
		// handle if this primitive doesn't exist.
		return prim_type(type_name);
	}

	Type get_symbol_type(string sym_name, Type_Variable[string] generics) {
		Type t = get_type(sym_name, generics);
		if (t !is null) {
			return t;
		}

		logger.Error("unhandled symbol lookup ", sym_name);
		return null;
	}

	// TODO this needs to be done properly...
	Type analyze_path(Path_Expression_Node path, Type_Variable[string] generics) {
		auto fst = path.values[0];
		Type t = analyze(fst, e, generics);
		return t;
	}

	Type analyze_call(Call_Node call, Type_Variable[string] generics) {
		Type func = analyze(call.left, e, generics);
		assert(func !is null);

		if (auto f = cast(Function) func) {
			// TODO check length of arguments

			foreach (i, arg; f.types) {
				unify(analyze(call.args[i], e, generics), arg);
			}

			return f.ret;
		}
		assert(0);
	}

	Type analyze_variable(Variable_Statement_Node node, Type_Variable[string] generics) {
		if (node.type !is null) {
			// resolve the type we're given.
			return analyze(node.type, e, generics);
		}

		// we have to infer the type from the value of the
		// expression instead. TODO handle no expression! (error)
		auto resolved = analyze(node.value, e, generics);
		node.type = resolve(node.type, resolved);
		return resolved;
	}

	Type analyze(ast.Node node, Type_Environment e) {
		Type_Variable[string] generics;
		return analyze(node, e, generics);
	}

	Type analyze(ast.Node node, Type_Environment e, Type_Variable[string] generics) {
		this.e = e;

		if (auto prim = cast(Primitive_Type_Node) node) {
			return analyze_primitive(prim, generics);
		}
		else if (auto var = cast(Variable_Statement_Node) node) {
			return analyze_variable(var, generics);
		}
		else if (auto binary = cast(Binary_Expression_Node) node) {
			auto left = analyze(binary.left, e, generics);
			auto right = analyze(binary.right, e, generics);
			unify(left, right);
			return left;
		}
		else if (auto paren = cast(Paren_Expression_Node) node) {
			return analyze(paren.value, e, generics);
		}
		else if (auto sym = cast(Symbol_Node) node) {
			return get_symbol_type(sym.value.lexeme, generics);
		} // this is mostly like
		// module.sub_mod.Type
		// Type
		// etc.
		// TODO: support module access		
		else if (auto path_type = cast(ast.Type_Path_Node) node) {
			auto type = path_type.values[0];
			Type t = e.lookup_type(type.lexeme);
			if (t is null) {
				logger.Error("Failed to resolve type '" ~ colour.Bold(
						type.lexeme) ~ "':", Blame_Token(type));
			}
			return t;
		}
		else if (auto path = cast(ast.Path_Expression_Node) node) {
			// TODO!
			return analyze_path(path, generics);
		}
		else if (auto unary = cast(ast.Unary_Expression_Node) node) {
			return analyze(unary.value, e, generics);
		}
		else if (auto cast_expr = cast(ast.Cast_Expression_Node) node) {
			return analyze(cast_expr.left, e, generics);
		}
		else if (auto call = cast(ast.Call_Node) node) {
			return analyze_call(call, generics);
		} // constants
		else if (cast(Integer_Constant_Node) node) {
			return prim_type("s32");
		}
		else if (cast(Float_Constant_Node) node) {
			// the widest type for floating point
			return prim_type("f64"); // "double"
		}
		else if (cast(Boolean_Constant_Node) node) {
			return prim_type("bool");
		}
		else if (cast(String_Constant_Node) node) {
			return prim_type("string");
		}
		else if (cast(Rune_Constant_Node) node) {
			return prim_type("rune");
		}

		logger.Fatal("infer: unhandled node " ~ to!string(node));
		assert(0);
	}
}