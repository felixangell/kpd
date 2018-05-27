module kir.conv_type;

import std.stdio;
import std.conv : to;

import sema.symbol;
import sema.infer : Type_Environment;
import compiler_error;
import diag.engine;
import logger;
import ast;
import sema.type;

Type get_sym_type(Type_Environment env, ast.Symbol_Node sym) {
	if (sym.resolved_symbol is null) {
		logger.fatal("Unresolved symbol node leaking! ", to!string(sym), " ... ", to!string(typeid(sym)),
			"\n", logger.blame_token(sym.get_tok_info()));
		return new Void();
	}

	if (auto sym_val = cast(Symbol_Value) sym.resolved_symbol) {
		if (sym_val.reference is null) {
			assert(0); // undefined!
		}
		return env.conv_type(sym_val.reference);
	}

	assert(0);
}

Type get_array_type(Type_Environment env, Array_Type_Node arr) {
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

	return new Array(env.conv_type(arr.base_type), res.value);
}

Type conv_prim_type(ast.Primitive_Type_Node node) {
	return conv_prim(node.type_name.lexeme);
}

Type get_type_path_type(Type_Environment env, Type_Path_Node t) {
	assert(t.values.length == 1);

	auto type = env.lookup_type(t.values[0].lexeme);
	if (type is null) {
		logger.error(t.get_tok_info(), "Un-declared type is leaking!");
		assert(0);
	}
	return type;
}

// convert an AST type to a krug ir type
Type conv_type(Type_Environment env, Node t) {
	assert(t !is null, "get_type null type");

	if (auto prim = cast(Primitive_Type_Node) t) {
		return conv_prim_type(prim);
	}
	else if (auto arr = cast(Array_Type_Node) t) {
		return env.get_array_type(arr);
	}
	else if (auto ptr = cast(Pointer_Type_Node) t) {
		return new Pointer(env.conv_type(ptr.base_type));
	}
	else if (auto c = cast(Cast_Expression_Node) t) {
		return conv_type(env, c.type);
	}

	else if (auto i = cast(Integer_Constant_Node) t) {
		// FIXME
		return get_int(true, 32);
	}

	else if (auto idx = cast(Index_Expression_Node) t) {
		Type type = env.conv_type(idx.array);	
		
		if (auto a = cast(Array) type) {
			return a.base;
		}
		else if (auto ptr = cast(Pointer) type) {
			return ptr.base;
		}

		// weird
		assert(0);
	}

	else if (auto path = cast(Path_Expression_Node) t) {
		// FIXME
		return env.conv_type(path.values[$-1]);
	}
	else if (auto sym = cast(Symbol_Node) t) {
		return env.get_sym_type(sym);
	}
	else if (auto var = cast(Variable_Statement_Node) t) {
		if (var.type !is null) {
			return env.conv_type(var.type);
		}

		auto inferred_type = env.lookup_type(var.twine.lexeme);
		if (inferred_type is null) {
			logger.error(var.get_tok_info(), "Un-inferred type is leaking!");
			assert(0);
		}
		return inferred_type;
	}
	else if (auto fn = cast(Function_Node) t) {
		// void...
		if (fn.return_type is null) {
			return new Void();
		}
		return env.conv_type(fn.return_type);
	}
	else if (auto bin = cast(Binary_Expression_Node) t) {
		// FIXME
		// the assumption here is based off
		// the binary expression should have 
		// the left and right hand expressions types
		// unified from type inference
		return env.conv_type(bin.left);
	}
	else if (auto unary = cast(Unary_Expression_Node) t) {
		return env.conv_type(unary.value);
	}
	else if (auto param = cast(Function_Parameter) t) {
		return env.conv_type(param.type);
	}
	else if (auto type_path = cast(Type_Path_Node) t) {
		return env.get_type_path_type(type_path);
	}

	logger.error(t.get_tok_info().get_tok(),
		"Leaking unresolved type:\n\t" ~ to!string(t) ~ "\n\t" ~ to!string(typeid(t)));

	// FIXME
	assert(0);
}