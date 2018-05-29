module sema.infer;

import std.conv;
import std.stdio;
import std.algorithm : cmp;

import diag.engine;
import compiler_error;
import krug_module;
import logger;
import sema.type;
import sema.symbol : Symbol_Table;
import ast;
import colour;
import tok;

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

	this(Type_Environment parent = null) {
		this.parent = parent;

		// an optimisation.. we store all of the 
		// common primitives in every new Type_Environment
		// (we could also copy) so that we dont have
		// to search N layers outwards
		//
		// this is because N could be 284592843 (though... unrealistic)
		// and we don't want to have to do 284592843 calls to get
		// a boolean type!
		register_type("true", get_bool());
		register_type("false", get_bool());
	}

	Type[string] data;

	Type lookup_type(string name) {
		import object : hashOf;
		logger.verbose("Looking up type for ", name, " IN#", to!string(this.hashOf()));

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
		import object : hashOf;
		logger.verbose("---- Registering type ", key, " : ", to!string(t), " IN#", to!string(this.hashOf()));

		if ((key in data)) {
			logger.verbose("Type ", key, " has already been registered!?");
			assert(0);
		}
		data[key] = t;
	}
}

// FIXME this is hacky. 
Token[Type] type_token_info;

Absolute_Token get_type_tok(Type t) {
	if (t in type_token_info) {
		return new Absolute_Token(type_token_info[t]);
	}

	writeln("no token information for type " ~ to!string(t));
	return null;
}

Type attach(Type type, Token token) {
	type_token_info[type] = token;
	return type;
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
			// there is no need to copy 
			// primitive types...
			if (op.name in PRIMITIVE_TYPES) {
				return op;
			}

			// ... FIXME!

			Type[] types;
			types.length = op.types.length;
			foreach (i, typ; op.types) {
				types[i] = fresh_type(typ, generics);
			}
			return new Type_Operator(op.get_name(), types);
		}
		else if (auto fn = cast(Fn) pt) {
			Type[] types;
			types.length = fn.types.length;

			foreach (i, typ; fn.types) {
				types[i] = fresh_type(typ, generics);
			}

			return new Fn(fresh_type(fn.ret, generics), types);
		}
		else if (auto st = cast(Structure) pt) {
			// TODO
			return st;
		}
		else if (auto tuple = cast(Tuple) pt) {
			// TODO
			return tuple;
		}
		else if (auto ar = cast(Array) pt) {
			return ar;
		}
		else if (auto ptr = cast(Pointer) pt) {
			return new Pointer(fresh_type(ptr.base, generics));
		}

		logger.fatal("unimplemented fresh type! ", to!string(typeid(pt)));
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
				string[] names = [
					to!string(a),
					to!string(b),
				];
				Diagnostic_Engine.throw_error(TYPE_MISMATCH, names, get_type_tok(a), get_type_tok(b));
				assert(0);
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

class Type_Inferrer {
	Module mod;
	Type_Environment e;

	this(Module mod) {
		this.mod = mod;
	}

	Type get_type(string name, Type_Variable[string] generics) {
		auto t = e.lookup_type(name);
		if (t !is null) {
			logger.verbose("Found '", name, "', type is ", to!string(t));
			return fresh(t, generics);
		}

		logger.error("Couldn't find type '", name, "' in environment:");
		assert(0);
	}

	Type analyze_primitive(ast.Primitive_Type_Node node, Type_Variable[string] generics) {
		return conv_prim(node.type_name.lexeme);
	}

	Type get_symbol_type(string sym_name, Type_Variable[string] generics) {
		Type t = get_type(sym_name, generics);
		if (t !is null) {
			return t;
		}

		logger.error("unhandled symbol lookup ", sym_name);
		return null;
	}

	Type analyze_cast(Cast_Expression_Node c, Type_Variable[string] generics) {
		Type t = analyze(c.type, e, generics);
		Type val = analyze(c.left, e, generics);
		// TODO
		// check if we can cast from val -> t
		// throw errors etc...
		// or we should maybe do this later in type checks?
		// also we nee a way to get around this if we wanted to
		return t;
	}

	Type analyze_sym_via(Type last, Symbol_Node sym, Type_Environment e, Type_Variable[string] generics) {
		if (auto structure = cast(Structure) last) {
			auto type = structure.get_field_type(sym.value.lexeme);
			assert(type !is null);
			return type;
		}
		else if (auto tuple = cast(Tuple) last) {
			auto type = tuple.nth(to!int(sym.value.lexeme));
			assert(type !is null);
			return type;
		}
		else if (auto ptr = cast(Pointer) last) {
			return ptr.base;
		}

		logger.error("unhandled type " ~ to!string(last));
		assert(0);
	}

	// FIXME
	Type analyze_via(Type last, Node n, Type_Environment e, Type_Variable[string] generics) {
		if (auto sym = cast(Symbol_Node) n) {
			return analyze_sym_via(last, sym, e, generics);
		}
		else if (auto integer = cast(Integer_Constant_Node) n) {
			// again tuple hack here to wrap
			// the number as a symbol node.
			return analyze_sym_via(last, new Symbol_Node(integer.tok), e, generics);
		}

		logger.error(n.get_tok_info(), "unhandled node " ~ to!string(typeid(n)));
		assert(0);
	}

	Type analyze_mod_access(Module_Access_Node man, Type_Variable[string] generics) {
		Symbol_Node left = man.left;

		auto table = cast(Symbol_Table) left.resolved_symbol;
		if (table is null) {
			writeln("oh shit unresolved symbol here? ", left);
			assert(0);
		}

		auto type = analyze_expr_list(generics, table.env, man.right);
		if (type is null) {
			// unresolved?
			assert(0, "unresolved!");
		}
		return type;
	}

	Type analyze_expr_list(Type_Variable[string] generics, Type_Environment env, Expression_Node[] expr...) {
		Type last = null;
		foreach (ref idx, val; expr) {
			if (last !is null) {
				last = analyze_via(last, val, env, generics);
			}
			else {
				last = analyze(val, env, generics);
			}
		}
		return last;
	}

	// TODO this needs to be done properly...
	Type analyze_path(Path_Expression_Node path, Type_Variable[string] generics) {
		logger.verbose("analyzing path ", to!string(path));
		Type last = analyze_expr_list(generics, e, path.values);
		if (last is null) {
			// TODO handle me
		}
		return last;
	}

	Type analyze_index(ast.Index_Expression_Node index, Type_Variable[string] generics) {
		Type left = analyze(index.array, e, generics);
		assert(left !is null);
		if (auto a = cast(Array) left) {
			return a.base;
		}
		assert(0);
	}

	Type analyze_call(Call_Node call, Type_Variable[string] generics) {
		Type func = analyze(call.left, e, generics);
		assert(func !is null);

		if (auto f = cast(Fn) func) {
			// TODO check length of arguments

			foreach (i, arg; f.types) {
				unify(analyze(call.args[i], e, generics), arg);
			}

			return f.ret;
		}
		assert(0);
	}

	// NOTE: we set the type to a new Void()
	// if it is null, i.e. specifying a type after
	// the function is optional during parsing as
	// we assume it is void. THIS part of the compiler
	// is where we actually set it to be void!
	Type analyze_func(ast.Function_Node node, Type_Variable[string] generics) {
		Type ret_type = new Void();
		if (node.return_type !is null) {
			ret_type = analyze(node.return_type, e, generics);
		}

		Type[] args;

		// TODO function receiver.
		foreach (i, param; node.params) {
			auto param_type = analyze(param.type, e, generics);
			args ~= param_type;
		}

		return new Fn(ret_type, args);
	}

	Type analyze_lambda(Lambda_Node lambda, Type_Variable[string] generics) {
		return analyze(lambda.func_type, e, generics);
	}

	Type analyze_variable(Variable_Statement_Node node, Type_Variable[string] generics) {
		if (node.type !is null) {
			// resolve the type we're given.
			return analyze(node.type, e, generics);
		}

		// we have to infer the type from the value of the
		// expression instead. TODO handle no expression! (error)
		auto resolved = analyze(node.value, e, generics);
		return resolved;
	}

	Type analyze(ast.Node node, Type_Environment e) {
		Type_Variable[string] generics;
		return analyze(node, e, generics);
	}

	Type analyze(ast.Node node, Type_Environment e, Type_Variable[string] generics) {
		this.e = e;

		// TODO analyzing function _TYPE_ nodes.

		if (auto func = cast(Function_Node) node) {
			return analyze_func(func, generics);
		}
		else if (auto prim = cast(Primitive_Type_Node) node) {
			return analyze_primitive(prim, generics).attach(prim.get_tok_info().get_tok());
		}
		else if (auto var = cast(Variable_Statement_Node) node) {
			return analyze_variable(var, generics);
		}
		else if (auto binary = cast(Binary_Expression_Node) node) {
			auto left = analyze(binary.left, e, generics);
			auto right = analyze(binary.right, e, generics);
			
			switch (binary.operand.lexeme) {
			case "==":
			case "!=":
			case ">=":
			case "<=":
			case ">":
			case "<":
			case "&&":
			case "||":
				return get_bool();
			default:
				break;
			}

			unify(left, right);
			return left;
		}
		else if (auto paren = cast(Paren_Expression_Node) node) {
			return analyze(paren.value, e, generics);
		}
		else if (auto sym = cast(Symbol_Node) node) {
			auto sym_type = get_symbol_type(sym.value.lexeme, generics);
			if (sym_type is null) {
				logger.error(sym.get_tok_info().get_tok(), "failed to lookup symbol!");
			}
			return sym_type;
		} 

		// this is mostly like
		// module.sub_mod.Type
		// Type
		// etc.
		// TODO: support module access		
		
		else if (auto path_type = cast(ast.Type_Path_Node) node) {
			auto type = path_type.values[0];
			Type t = e.lookup_type(type.lexeme);
			if (t is null) {
				logger.error("Failed to resolve type '" ~ colour.Bold(type.lexeme) ~ "':\n", blame_token(type));
				assert(0);
			}
			return t;
		}

		else if (auto path = cast(ast.Path_Expression_Node) node) {
			// TODO!
			return analyze_path(path, generics)
				.attach(path.values[$-1].get_tok_info.get_tok());
		}

		else if (auto man = cast(ast.Module_Access_Node) node) {
			return analyze_mod_access(man, generics);
		}

		else if (auto unary = cast(ast.Unary_Expression_Node) node) {
			return analyze(unary.value, e, generics);
		}
		else if (auto cast_expr = cast(ast.Cast_Expression_Node) node) {
			return analyze_cast(cast_expr, generics);
		}
		else if (auto call = cast(ast.Call_Node) node) {
			return analyze_call(call, generics);
		} 
		else if (auto idx = cast(Index_Expression_Node) node) {
			return analyze_index(idx, generics);
		}

		// constants
		else if (cast(Integer_Constant_Node) node) {
			return get_int(true, 32).attach(node.get_tok_info().get_tok());
		}
		else if (cast(Float_Constant_Node) node) {
			// the widest type for floating point
			return get_float(true, 64).attach(node.get_tok_info().get_tok()); // "double"
		}
		else if (cast(Boolean_Constant_Node) node) {
			return get_bool().attach(node.get_tok_info().get_tok());
		}
		else if (auto str = cast(String_Constant_Node) node) {
			if (str.type == String_Type.C_STYLE) {
				return new Pointer(get_int(false, 8)).attach(node.get_tok_info().get_tok());
			}
			return get_string();
		}
		else if (cast(Rune_Constant_Node) node) {
			return get_rune().attach(node.get_tok_info().get_tok());
		}

		else if (auto lambda = cast(ast.Lambda_Node) node) {
			return analyze_lambda(lambda, generics);
		}

		else if (auto structure = cast(Structure_Type_Node) node) {
			Type[] types;
			string[] names;
			Expression_Node[ulong] values;
			foreach (ref idx, field; structure.fields) {
				types ~= analyze(field.type, e, generics);
				// TODO attach token info to this type.
				names ~= field.name.lexeme;
				
				if (field.value !is null) {
					values[idx] = field.value;
				}
			}
			return new Structure(types, names, values);
		}

		else if (auto tuple = cast(Tuple_Type_Node) node) {
			Type[] types;
			foreach (ref type; tuple.types) {
				types ~= analyze(type, e, generics);
			}
			return new Tuple(types);
		}

		else if (auto ptr = cast(Pointer_Type_Node) node) {
			return new Pointer(analyze(ptr.base_type, e, generics));
		}
		else if (auto arr = cast(Array_Type_Node) node) {
			// FIXME this is a straightup copy/paste from the builder.d

			import kir.eval;

			auto res = try_evaluate_expr(arr.value);
			if (res.failed) {
				auto blame = arr.base_type.get_tok_info();
				if (arr.value !is null) {
					blame = arr.value.get_tok_info();
				}
				Diagnostic_Engine.throw_error(COMPILE_TIME_EVAL, blame, blame);
				assert(0);
			}

			return new Array(analyze(arr.base_type, e, generics), res.value);
		}

		logger.error(node.get_tok_info(), "infer: unhandled node " ~ to!string(node) ~ " ... " ~ to!string(typeid(node)));
		assert(0);
	}
}