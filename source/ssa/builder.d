module ssa.builder;

import std.stdio;
import std.range.primitives;
import std.conv;
import std.traits;

import ssa.instr;
import ssa.block;
import sema.visitor;
import ssa.ir_module;

import logger;
import ast;
import logger;
import krug_module;

T pop(T)(ref T[] array) {
  T val = array.back;
  array.popBack();
  return val;
}

uint temp = 0;
string gen_temp() {
  return "t" ~ to!string(temp++);
}

/*
https://pp.ipd.kit.edu/uploads/publikationen/braun13cc.pdf
*/
class SSA_Builder : Top_Level_Node_Visitor {

  IR_Module ir_mod;
  Basic_Block* curr_block;

  this() {
    ir_mod = new IR_Module();
  }

  override void analyze_named_type_node(ast.Named_Type_Node) {}

  void build_block(ast.Block_Node block) {
    auto stats = block.statements;
    
  }

  // we generate one control flow graph per function
  // convert the ast.Block_Node into a bunch of basic blocks
  // 
  // the flow can only enter via the FIRST instruction of the
  // basic block
  // control will leave the block without halting or branching
  // basic block is a node in a control flow graph.
  //
  // 1. the first instruction is a leader.
  // 2. any instruction that is the target of a jump is a leader.
  // 3. any instruction that follows a jump is a leader.
  override void analyze_function_node(ast.Function_Node func) {
    auto ssa_func = ir_mod.add_function(func.name.lexeme);
    Basic_Block block = ssa_func.push_block();
    curr_block = &block;

    if (func.func_body !is null) {
      build_block(func.func_body);      
    }
  }

  // this is likely a store
  // a = b + f * -c ... 
  void build_binary_expr(ast.Binary_Expression_Node binary) {
    Value[] expr_stack;
    Token[] operands;

    void delegate(Expression_Node) build_bin;
    build_bin = delegate(ast.Expression_Node expr) {      
      if (auto binary = cast(Binary_Expression_Node) expr) {
        build_bin(binary.left);
        build_bin(binary.right);
        operands ~= binary.operand;
      }

      else if (auto paren = cast(Paren_Expression_Node) expr) {
        build_bin(paren.value);
      }

      // TODO flatten calls properly?
      else if (auto call = cast(Call_Node) expr) {
        foreach (arg; call.args) {
          build_bin(arg);
        }
      }

      else {
        expr_stack ~= new Constant(expr);
      }
    };
    build_bin(binary);

    Value[string] names;
    Value[] values;

    while (operands.length > 0) {
      Token op = operands.pop();
      auto a = expr_stack.pop();
      auto b = expr_stack.pop();

      auto temp = new BinaryOp(null, op, a, b);
      auto temp_name = gen_temp();
      names[temp_name] = temp;
      expr_stack ~= new Identifier(temp_name); 
      
      values ~= temp;
    }

    foreach (v; values) {
      writeln(v);
    }
  }

  void build_expr(ast.Expression_Node expr) {
    if (auto binary = cast(ast.Binary_Expression_Node) expr) {
      build_binary_expr(binary);
    } else {
      logger.Warn("ssa_builder: unhandled expr ", to!string(expr));
    }
  }

  override void analyze_let_node(ast.Variable_Statement_Node var) {
    if (var.value !is null) {
      build_expr(var.value);
    }
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