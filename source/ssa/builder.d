module ssa.builder;

import std.conv;

import ssa.instr;
import ssa.block;
import sema.visitor;
import ssa.ir_module;

import logger;
import ast;
import logger;
import krug_module;

// https://pp.ipd.kit.edu/uploads/publikationen/braun13cc.pdf
class SSA_Builder : Top_Level_Node_Visitor {

  IR_Module ir_mod;
  Basic_Block* curr_block;

  this() {
    ir_mod = new IR_Module();
  }

  override void analyze_named_type_node(ast.Named_Type_Node) {}

  override void analyze_function_node(ast.Function_Node func) {
    auto ssa_func = ir_mod.add_function(func.name.lexeme);
    Basic_Block block = ssa_func.push_block();
    curr_block = &block;

    if (func.func_body !is null) {
      visit_block(func.func_body);
    }
  }

  override void analyze_let_node(ast.Variable_Statement_Node var) {
    
  }

  override void visit_stat(ast.Statement_Node node) {
    if (auto let = cast(ast.Variable_Statement_Node) node) {
      analyze_let_node(let);
    } else {
      logger.Warn("unhandled node in ssa ", to!string(node));
    }
  }

	IR_Module build(ref Module mod, string sub_mod_name) {
		assert(mod !is null);

    if (sub_mod_name !in mod.as_trees) {
      logger.Error("couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
      return null;
    }

    curr_sym_table = mod.sym_tables[sub_mod_name];

    auto ast = mod.as_trees[sub_mod_name];
    foreach (node; ast) {
      super.process_node(node);
    }

    ir_mod.dump();

    return ir_mod;
	}
}