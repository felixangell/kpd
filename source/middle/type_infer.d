module sema.type_infer_pass;

import std.conv;
import std.stdio;

import logger;
import ast;
import sema.visitor;
import sema.analyzer : Semantic_Pass;
import sema.symbol;
import diag.engine;
import sema.type;
import sema.infer;
import krug_module;
import compiler_error;

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
		logger.Verbose("-- (", to!string(var), ") : ", to!string(inferred_type));
	}

	void analyze_while_loop(ast.While_Statement_Node loop) {
		auto infer = inferrer.analyze(loop.condition, curr_sym_table.env);
	}

	override void analyze_function_node(ast.Function_Node node) {
		// some functions have no body!
		// these are prototype functions
		if (node.func_body !is null) {
			visit_block(node.func_body);
		}
	}

	override void visit_stat(ast.Statement_Node stat) {
		if (auto variable = cast(ast.Variable_Statement_Node) stat) {
			analyze_let_node(variable);
		}
		else if (auto loop = cast(ast.While_Statement_Node) stat) {
			analyze_while_loop(loop);
		}
		else {
			logger.Fatal("type_infer: unhandled statement " ~ to!string(stat));
		}
	}

	override void execute(ref Module mod, string sub_mod_name) {
		assert(mod !is null);
		this.mod = mod;

		if (sub_mod_name !in mod.as_trees) {
			logger.Error("couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
			return;
		}

		// current = mod.scopes[sub_mod_name];
		curr_sym_table = mod.sym_tables[sub_mod_name];

		auto ast = mod.as_trees[sub_mod_name];
		foreach (node; ast) {
			if (node !is null) {
				super.process_node(node);
			}
		}
	}

	override string toString() const {
		return "top-level-type-decl-pass";
	}

}
