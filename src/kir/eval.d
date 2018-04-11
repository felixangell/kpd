module kir.eval;

import std.conv : to;
import std.typecons : Tuple;
import std.stdio;

import logger;
import ast;

alias MaybeValue = Tuple!(bool, "failed", ulong, "value");

auto try_evaluate_expr(ast.Expression_Node e) {
	if (e is null) {
		return MaybeValue(true, 0);
	}

	auto eval(ast.Expression_Node e) {
		if (auto iconst = cast(ast.Integer_Constant_Node) e) {
			return MaybeValue(false, cast(ulong) iconst.value);
		}
		else {
			logger.fatal("unhandled expression " ~ to!string(typeid(e)));
		}
		return MaybeValue(true, 0);
	}

	return eval(e);
}