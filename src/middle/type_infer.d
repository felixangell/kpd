module sema.type_infer_pass;

import std.conv;
import std.stdio;

import logger;
import ast;
import sema.visitor;
import sema.analyzer;
import sema.symbol;
import diag.engine;
import sema.type;
import sema.infer;
import krug_module;
import compiler_error;

// quick hack for 
// simple type comparisons
private bool cmp_type(Type t, string name) {
	if (auto to = cast(Type_Operator) t) {
		if (to.types.length == 0 && t.name == name) {
			return true;
		}
	}
	return false;
}

class Type_Infer_Pass : Top_Level_Node_Visitor, Semantic_Pass {
	Type_Inferrer inferrer;

	override void analyze_named_type_node(ast.Named_Type_Node node) {
		// TODO?
	}

	// FIXME!
	// TODO think of a way to attach the sema types to ast 
	// nodes without causing a weird cyclic dependency thing!
	override void analyze_var_stat_node(ast.Variable_Statement_Node var) {
		// there is no value or type so the type inferrer
		// doesn't have anything to work with.
		if (var.value is null && var.type is null) {
			Diagnostic_Engine.throw_error(NO_TYPE_ANNOTATION, var.get_tok_info());
			return;
		}

		auto inferred_type = inferrer.analyze(var, curr_sym_table.env);
		
		// insert the inferred type into
		// the current environment
		curr_sym_table.env.register_type(var.twine.lexeme, inferred_type);

		this.log(Log_Level.Verbose, "-- (", to!string(var), ") : ", to!string(inferred_type));
	}

	void analyze_expr(ast.Expression_Node expr) {
		auto type = inferrer.analyze(expr, curr_sym_table.env);
		if (type is null) {
			this.log(Log_Level.Error, "unimplemented/failed to infer: ", to!string(expr), " ... ", to!string(typeid(expr)), 
				"\n", logger.blame_token(expr.get_tok_info()));
		}
	}

	void analyze_while_loop(ast.While_Statement_Node loop) {
		auto while_type = inferrer.analyze(loop.condition, curr_sym_table.env);
		unify(while_type, get_bool());
	}

	void analyze_for_loop(ast.For_Statement_Node loop) {
		auto cond_type = inferrer.analyze(loop.condition, curr_sym_table.env);
		unify(cond_type, get_bool());

		auto step_type = inferrer.analyze(loop.step, curr_sym_table.env);
	}

	void analyze_if_stat(ast.If_Statement_Node iff) {
		auto if_type = inferrer.analyze(iff.condition, curr_sym_table.env);
		unify(if_type, get_bool());
	}

	void analyze_else_if_stat(ast.Else_If_Statement_Node else_if) {
		auto else_if_type = inferrer.analyze(else_if.condition, curr_sym_table.env);
		unify(else_if_type, get_bool());
	}

	void analyze_else_stat(ast.Else_Statement_Node else_stat) {
		assert(0);
	}

	void analyze_ret(ast.Return_Statement_Node ret) {
		if (ret.value is null) {
			return;
		}
		auto ret_type = inferrer.analyze(ret.value, curr_sym_table.env);
	}

	void analyze_call(ast.Call_Node call) {
		// TODO
		inferrer.analyze(call, curr_sym_table.env);
	}

	override void analyze_function_node(ast.Function_Node node) {
		// some functions have no body!
		// these are prototype functions
		if (node.func_body is null) {
			return;
		}

		visit_block(node.func_body, delegate(Symbol_Table stab) {
			foreach (p; node.params) {
				auto p_type = inferrer.analyze(p.type, stab.env);
				stab.env.register_type(p.twine.lexeme, p_type);	
			}
		});
	}

	void analyze_structure_destructure(ast.Structure_Destructuring_Statement_Node stat) {
		analyze_expr(stat.rhand);		
	}

	void analyze_match(ast.Switch_Statement_Node match) {
		analyze_expr(match.condition);

		// TODO scope etc.
		foreach (a; match.arms) {
			foreach (v; a.expressions) {
				analyze_expr(v);
			}
			visit_block(a.block);
		}
	}

	override void visit_stat(ast.Statement_Node stat) {
		if (auto variable = cast(ast.Variable_Statement_Node) stat) {
			analyze_var_stat_node(variable);
		}
		else if (auto loop = cast(ast.While_Statement_Node) stat) {
			analyze_while_loop(loop);
		}
		else if (auto for_loop = cast(ast.For_Statement_Node) stat) {
			analyze_for_loop(for_loop);
		}
		else if (auto iff = cast(ast.If_Statement_Node) stat) {
			analyze_if_stat(iff);
		}
		else if (auto structure_destructure = cast(ast.Structure_Destructuring_Statement_Node) stat) {
			analyze_structure_destructure(structure_destructure);
		}
		else if (auto expr = cast(ast.Expression_Node) stat) {
			analyze_expr(expr);
		}
		else if (auto ret = cast(ast.Return_Statement_Node) stat) {
			analyze_ret(ret);
		}
		else if (auto call = cast(ast.Call_Node) stat) {
			analyze_call(call);
		}
		else if (auto loop = cast(ast.Loop_Statement_Node) stat) {
			// NOP
		}
		else if (auto defer = cast(ast.Defer_Statement_Node) stat) {
			visit_stat(defer.stat);
		}
		else if (auto block = cast(ast.Block_Node) stat) {
			visit_block(block);
		}
		else if (auto match = cast(ast.Switch_Statement_Node) stat) {
			analyze_match(match);	
		}
		else if (cast(ast.Else_If_Statement_Node) stat) {
			assert(0);
		}
		else if (cast(ast.Else_Statement_Node) stat) {
			assert(0);
		}
		else {
			this.log(Log_Level.Error, "unhandled statement " ~ to!string(stat) ~ " ... " ~ to!string(typeid(stat)),
				"\n", logger.blame_token(stat.get_tok_info()));
		}
	}

	override void execute(ref Module mod, string sub_mod_name, AST as_tree) {
		this.inferrer = new Type_Inferrer(mod);

		foreach (node; as_tree) {
			if (node !is null) {
				super.process_node(node);
			}
		}
	}

	override string toString() const {
		return "type-infer-pass";
	}

}
