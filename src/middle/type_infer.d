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
	Module mod;
	Type_Inferrer inferrer;

	override void analyze_named_type_node(ast.Named_Type_Node node) {
		
	}

	override void analyze_let_node(ast.Variable_Statement_Node var) {
		// there is no value or type so the type inferrer
		// doesn't have anything to work with.
		if (var.value is null && var.type is null) {
			Diagnostic_Engine.throw_error(NO_TYPE_ANNOTATION, var.twine);
			return;
		}

		// there is no value to infer from.
		// but we _should_ have a type.
		if (var.value is null) {
			return;
		}

		auto inferred_type = inferrer.analyze(var, curr_sym_table.env);
		
		// insert the inferred type into
		// the current environment
		curr_sym_table.env.register_type(var.twine.lexeme, inferred_type);

		var.type = new Resolved_Type(var.type, inferred_type);
		this.log(Log_Level.Verbose, "-- (", to!string(var), ") : ", to!string(inferred_type));
	}

	void analyze_while_loop(ast.While_Statement_Node loop) {
		auto while_type = inferrer.analyze(loop.condition, curr_sym_table.env);
	}

	void analyze_iff(ast.If_Statement_Node iff) {
		auto if_type = inferrer.analyze(iff.condition, curr_sym_table.env);
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

	override void visit_stat(ast.Statement_Node stat) {
		if (auto variable = cast(ast.Variable_Statement_Node) stat) {
			analyze_let_node(variable);
		}
		else if (auto loop = cast(ast.While_Statement_Node) stat) {
			analyze_while_loop(loop);
		}
		else if (auto iff = cast(ast.If_Statement_Node) stat) {
			analyze_iff(iff);
		}
		else if (auto ret = cast(ast.Return_Statement_Node) stat) {
			analyze_ret(ret);
		}
		else if (auto call = cast(ast.Call_Node) stat) {
			analyze_call(call);
		}
		else {
			this.log(Log_Level.Error, "unhandled statement " ~ to!string(stat));
		}
	}

	override void execute(ref Module mod, string sub_mod_name) {
		assert(mod !is null);
		this.mod = mod;

		if (sub_mod_name !in mod.as_trees) {
			this.log(Log_Level.Error, "couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
			return;
		}

		curr_sym_table = mod.sym_tables[sub_mod_name];

		auto ast = mod.as_trees[sub_mod_name];
		foreach (node; ast) {
			if (node !is null) {
				super.process_node(node);
			}
		}
	}

	override string toString() const {
		return "type-infer-pass";
	}

}
