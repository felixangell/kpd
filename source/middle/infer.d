module sema.infer;

import std.conv;

import sema.type;
import ast;
import err_logger;

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
	}

	this() {
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

	Type[string] data;

	// for example we could register that
	// true -> bool
	// false -> bool
	// or add -> f(int, int) : int
	void register_type(string key, Type t) {
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

Type fresh(Type t) {
	Type fresh_type(Type type) {
		auto pt = prune(type);
		if (auto var = cast(Type_Variable) pt) {
			return var;
		}
		else if (auto op = cast(Type_Operator) pt) {
			Type[] types;
			types.length = op.types.length;

			foreach (i, typ; op.types) {
				types[i] = fresh_type(typ);
			}
			return new Type_Operator(op.get_name(), types);
		}
		else if (auto fn = cast(Function) pt) {
			Type[] types;
			types.length = fn.types.length;

			foreach (i, typ; fn.types) {
				types[i] = fresh_type(typ);
			}

			return new Function(fresh_type(fn.ret), types);
		}

		err_logger.Fatal("bad type!");
		assert(0);
	}
	return fresh_type(t);
}

void unify(Type a, Type b) {
	auto pa = prune(a);
	auto pb = prune(b);

	if (auto var = cast(Type_Variable)pa) {
		if (var != pb) {
			var.instance = pb;
		}	
	} 
	else if (auto opa = cast(Type_Operator)pa) {
		if (auto var = cast(Type_Variable)pb) {
			unify(var, opa);
		}
		else if (auto opb = cast(Type_Operator)pb) {
			// type mismatch here

			foreach (idx, t; opa.types) {
				unify(t, opb.types[idx]);
			}
		}
	}
}

Type prune(Type t) {
	if (auto var = cast(Type_Variable)t) {
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

	if (auto op = cast(Type_Operator)pb) {
		return occurs_in(a, op.types);
	}
	return false;
}

Type_Node resolve(Type_Node old, Type resolved) {
    return new Resolved_Type(old, resolved);
}

struct Type_Inferrer {
	Type_Environment e;

	Type get_type(string name) {
		if (name in e.data) {
			return fresh(e.data[name]);
		}

		// is string?
		// is char?
		// is int
		// is float

		assert(0);
	}

	Type analyze_primitive(ast.Primitive_Type_Node node) {
		auto type_name = node.type_name.lexeme;
		// handle if this primitive doesn't exist.
		return prim_type(type_name);
	}

	Type analyze_variable(Variable_Statement_Node node) {
		if (node.type !is null) {
			// resolve the type we're given.
			return analyze(node.type, e);
		}

		// we have to infer the type from the value of the
		// expression instead. TODO handle no expression! (error)
		auto resolved = analyze(node.value, e);
		node.type = resolve(node.type, resolved);
		return resolved;
	}

	Type analyze(ast.Node node, Type_Environment e) {
		this.e = e;

		if (auto prim = cast(Primitive_Type_Node)node) {
			return analyze_primitive(prim);
		}
		else if (auto var = cast(Variable_Statement_Node)node) {
			return analyze_variable(var);
		}
		else if (auto integer = cast(Integer_Constant_Node)node) {
			return prim_type("int");
		}
		else if (auto integer = cast(Float_Constant_Node)node) {
			// the widest type for floating point
			return prim_type("f64"); // "double"
		}
		else if (auto integer = cast(Boolean_Constant_Node)node) {
			return prim_type("bool");
		}
		else if (auto integer = cast(String_Constant_Node)node) {
			return prim_type("string");
		}
		else if (auto integer = cast(Rune_Constant_Node)node) {
			return prim_type("rune");
		}
		

		err_logger.Fatal("infer: unhandled node " ~ to!string(node));
		assert(0);
	}
}