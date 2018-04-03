module kir.eval;

import std.typecons : Tuple;

import ast;

alias MaybeValue = Tuple!(bool, "failed", ulong, "value");

auto try_evaluate_expr(ast.Expression_Node e) {
	return MaybeValue(true, 0);
}