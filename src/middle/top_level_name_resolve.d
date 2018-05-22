module sema.top_level_name_resolve;

import std.conv;
import std.stdio;

import logger;
import ast;
import sema.visitor;
import sema.analyzer;
import sema.symbol;
import diag.engine;
import sema.type;
import krug_module;
import tok;
import compiler_error;

class Top_Level_Name_Resolve_Pass : Top_Level_Node_Visitor, Semantic_Pass {
	Module mod;

	override void analyze_named_type_node(Named_Type_Node nt) {

	}

	override void analyze_function_node(Function_Node f) {
		
	}

	override void analyze_var_stat_node(Variable_Statement_Node var) {

	}

	override void visit_stat(Statement_Node stat) {

	}

	void execute(ref Module mod, string sub_mod_name, AST as_tree) {
		this.mod = mod;
		foreach (node; as_tree) {
			if (node !is null) {
				super.process_node(node);
			}
		}
	}

	override string toString() const {
		return "top-level-name-resolve-pass";
	}
}