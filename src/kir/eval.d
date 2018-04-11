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
		else if (auto fconst = cast(ast.Float_Constant_Node) e) {
			assert(0);
		}
		else if (auto binary = cast(ast.Binary_Expression_Node) e) {
			auto left = eval(binary.left);
			auto right = eval(binary.right);
			if (!left.failed && !right.failed) {
				ulong res = cast(ulong)left.value;
				switch (binary.operand.lexeme) {
				case "+":
					res += cast(ulong)right.value;
					break;
				default:
					assert(0);
				}
				return MaybeValue(false, res);
			}
			return MaybeValue(true, 0);
		}
		else if (auto paren = cast(ast.Paren_Expression_Node) e) {
			return eval(paren.value);
		}
		else {
			logger.fatal("unhandled expression " ~ to!string(typeid(e)));
		}
		return MaybeValue(true, 0);
	}

	return eval(e);
}