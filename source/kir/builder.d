module kir.builder;

import std.stdio;
import std.range.primitives;
import std.conv;
import std.traits;

import kir.instr;
import sema.visitor;
import kir.ir_mod;

import logger;
import ast;
import logger;
import krug_module;
import sema.infer : Type;
import sema.type : prim_type;

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
class Kir_Builder : Top_Level_Node_Visitor {

  Kir_Module ir_mod;
  Function curr_func;

  this() {
    ir_mod = new Kir_Module();
  }

  override void analyze_named_type_node(ast.Named_Type_Node) {}

  void build_block(ast.Block_Node block) {
    curr_func.push_block();

    foreach (stat; block.statements) {
      visit_stat(stat);
    }
  }

  // convert an AST type to a krug ir type
  Type get_type(Node t) {
    if (auto resolved = cast(Resolved_Type) t) {
      return resolved.type;
    } else if (auto prim = cast(Primitive_Type_Node) t) {
      return prim_type(prim.type_name.lexeme);
    } else if (auto sym = cast(Symbol_Node) t) {
      // TODO
      // since the type inference stuff passes
      // were temporarily removed
      // we dont know any of the type information
      // for nowe let's just assume we're dealing with ints!
      // otherwise we would want to lookup the type here!
      return prim_type("int");
    }

    logger.Error("Leaking unresolved type! ", to!string(t));

    // FIXME just pretend it's an integer for now!
    return prim_type("int");
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
    curr_func = ir_mod.add_function(func.name.lexeme);
    curr_func.push_block();

    // alloc all the params
    foreach (p; func.params.byValue()) {
      curr_func.add_alloc(new Alloc(get_type(p.type), p.twine.lexeme));
    }

    if (func.func_body !is null) {
      build_block(func.func_body);      
    }
  }

  void build_binary_expr(ast.Binary_Expression_Node binary) {
    
  }

  Value build_binary(ast.Binary_Expression_Node binary) {
    Value left = build_expr(binary.left);
    Value right = build_expr(binary.right);

    auto temp = new Alloc(left.get_type(), gen_temp());
    curr_func.add_instr(temp);

    auto expr = new BinaryOp(left.get_type(), binary.operand, left, right);
    auto store = new Store(left.get_type(), temp, expr);
    curr_func.add_instr(store);
    return new Identifier(temp.get_type(), temp.name);
  }

  Value build_expr(ast.Expression_Node expr) {
    if (auto integer_const = cast(Integer_Constant_Node) expr) {
      return new Constant(prim_type("int"), integer_const);
    } else if (auto binary = cast(Binary_Expression_Node) expr) {
      return build_binary(binary);
    } else if (auto path = cast(Path_Expression_Node) expr) {
       // FIXME
      return build_expr(path.values[0]);
    } else if (auto sym = cast(Symbol_Node) expr) {
      return new Identifier(get_type(sym), sym.value.lexeme);
    } else {
      logger.Fatal("unhandled build_expr in ssa ", to!string(expr));
    }
    return null;
  }

  override void analyze_let_node(ast.Variable_Statement_Node var) {
    // TODO handle global variables.
    auto addr = curr_func.add_alloc(new Alloc(get_type(var.type), var.twine.lexeme));

    if (var.value !is null) {
      auto val = build_expr(var.value);
      curr_func.add_instr(new Store(val.get_type(), addr, val));
    }
  }

  override void visit_stat(ast.Statement_Node node) {
    if (auto let = cast(ast.Variable_Statement_Node) node) {
      analyze_let_node(let);
    } else {
      logger.Warn("unhandled node in ssa ", to!string(node));
    }
  }

	Kir_Module build(ref Module mod, string sub_mod_name) {
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