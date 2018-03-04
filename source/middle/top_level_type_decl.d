module sema.top_level_type_decl;

import std.conv;
import std.stdio;

import logger;
import ast;
import sema.visitor;
import sema.analyzer : Semantic_Pass, log;
import sema.symbol;
import diag.engine;
import sema.type;
import krug_module;
import compiler_error;

class Top_Level_Type_Decl_Pass : Top_Level_Node_Visitor, Semantic_Pass {
	Module mod;

	override void analyze_named_type_node(ast.Named_Type_Node node) {

	}

	override void analyze_let_node(ast.Variable_Statement_Node var) {
		
	}

	override void analyze_function_node(ast.Function_Node node) {
		
	}

	override void visit_stat(ast.Statement_Node stat) {
		this.log(Log_Level.Error, "unhandled statement " ~ to!string(stat));
	}

	override void execute(ref Module mod, string sub_mod_name) {
		assert(mod !is null);
		this.mod = mod;

		if (sub_mod_name !in mod.as_trees) {
			logger.Error("couldn't find the AST for " ~ sub_mod_name ~
					" in module " ~ mod.name ~ " ...");
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
