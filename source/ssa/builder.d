module ssa.builder;

import ssa.instr;
import ssa.block;
import sema.visitor;

import ast;
import logger;
import krug_module;

// https://pp.ipd.kit.edu/uploads/publikationen/braun13cc.pdf
class SSA_Builder : Top_Level_Node_Visitor {

  override void analyze_named_type_node(ast.Named_Type_Node) {

  }

  override void analyze_function_node(ast.Function_Node) {

  }

  override void analyze_let_node(ast.Variable_Statement_Node) {

  }

  override void visit_stat(ast.Statement_Node) {

  }


	void build(ref Module mod, string sub_mod_name) {
		assert(mod !is null);

    if (sub_mod_name !in mod.as_trees) {
      logger.Error("couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
      return;
    }

    curr_sym_table = mod.sym_tables[sub_mod_name];

    auto ast = mod.as_trees[sub_mod_name];
    foreach (node; ast) {
      super.process_node(node);
    }
	}
}