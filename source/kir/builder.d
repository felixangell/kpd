module kir.builder;

import std.stdio;
import std.range.primitives;
import std.conv;
import std.traits;

import kir.instr;
import sema.visitor;
import kir.ir_mod;

import kt;
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

  Label build_block(ast.Block_Node block) {
    auto bb = curr_func.push_block();

    foreach (stat; block.statements) {
      visit_stat(stat);
    }

    return new Label(bb.name(), bb);
  }

  // convert a Type into a KIR Type.
  // note this Type is not a type node from
  // the AST but a Type from the type system
  kt.Kir_Type conv(Type t) {
    return null;
  }

  kt.Kir_Type conv_prim_type(ast.Primitive_Type_Node prim) {
    switch (prim.type_name.lexeme) {
    // signed integers
    case "s8": return get_int(8);
    case "s16": return get_int(16);
    case "s32": return get_int(32);
    case "s64": return get_int(64);

    // unsigned integers
    case "u8": return get_uint(8);
    case "u16": return get_uint(16);
    case "u32": return get_uint(32);
    case "u64": return get_uint(64);

    case "bool": return get_uint(8);
    case "rune": return get_uint(32);

    default: break;
    }

    logger.Error("Unhandled conversion of primitive type to kir type ", to!string(prim));
    return null;
  }

  // convert an AST type to a krug ir type
  kt.Kir_Type get_type(Node t) {
    if (auto resolved = cast(Resolved_Type) t) {
      return conv(resolved.type);
    } else if (auto prim = cast(Primitive_Type_Node) t) {
      return conv_prim_type(prim);
    } else if (auto sym = cast(Symbol_Node) t) {
      // TODO
      // since the type inference stuff passes
      // were temporarily removed
      // we dont know any of the type information
      // for nowe let's just assume we're dealing with ints!
      // otherwise we would want to lookup the type here!
      return get_int(32);
    } else if (auto arr = cast(Array_Type_Node) t) {
      return new kt.Array_Type(get_type(arr.base_type));
    }

    logger.Error("Leaking unresolved type! ", to!string(t));

    // FIXME just pretend it's an integer for now!
    return get_int(32);
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

  Value build_binary_expr(ast.Binary_Expression_Node binary) {
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
      // FIXME
      return new Constant(get_int(32), integer_const);
    } else if (auto binary = cast(Binary_Expression_Node) expr) {
      return build_binary_expr(binary);
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

  void analyze_return_node(ast.Return_Statement_Node ret) {    
    auto ret_instr = new Return(new Void_Type());

    // its not a void type
    if (ret.value !is null) {
      ret_instr.set_type(get_type(ret.value));
      ret_instr.results ~= build_expr(ret.value);
    }

    // TODO return values
    curr_func.add_instr(ret_instr);
  }

  void analyze_if_node(ast.If_Statement_Node if_stat) {
    Value condition = build_expr(if_stat.condition);

    If jmp = new If(condition);
    curr_func.add_instr(jmp);
    jmp.a = build_block(if_stat.block);

    // new block for else stuff
    jmp.b = new Label(curr_func.push_block());
  }

  void analyze_loop_node(ast.Loop_Statement_Node loop) {
    auto loop_body = build_block(loop.block);
    curr_func.add_instr(new Jump(loop_body));
  }

  void analyze_break_node(ast.Break_Statement_Node b) {
    // TODO
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
    } else if (auto ret = cast(ast.Return_Statement_Node) node) {
      analyze_return_node(ret);
    } else if (auto if_stat = cast(ast.If_Statement_Node) node) {
      analyze_if_node(if_stat);
    } else if (auto loop = cast(ast.Loop_Statement_Node) node) {
      analyze_loop_node(loop);
    } else if (auto b = cast(ast.Break_Statement_Node) node) {
      analyze_break_node(b);
    } else {
      logger.Warn("kir_builder: unhandled node: ", to!string(node));
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