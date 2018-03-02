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
    case "rune": return get_int(32);

    case "f32": return get_float(32);
    case "f64": return get_float(64);

    // TODO: what width should these types
    // be !
    case "int": return get_int(32);
    case "uint": return get_uint(32);

    case "void": return new Void_Type();

    default: break;
    }

    // TODO f32 and f64.

    logger.Error("Unhandled conversion of primitive type to kir type ", to!string(prim));
    return null;
  }

  // convert an AST type to a krug ir type
  kt.Kir_Type get_type(Node t) {
    if (auto resolved = cast(Resolved_Type) t) {
      return conv(resolved.type);
    } 
    else if (auto prim = cast(Primitive_Type_Node) t) {
      return conv_prim_type(prim);
    } 
    else if (auto sym = cast(Symbol_Node) t) {
      // TODO
      // since the type inference stuff passes
      // were temporarily removed
      // we dont know any of the type information
      // for nowe let's just assume we're dealing with ints!
      // otherwise we would want to lookup the type here!
      return get_int(32);
    } 
    else if (auto arr = cast(Array_Type_Node) t) {
      return new kt.Array_Type(get_type(arr.base_type));
    } 
    else if (auto ptr = cast(Pointer_Type_Node) t) {
      return new kt.Pointer_Type(get_type(ptr.base_type));
    }

    if (t is null) {
      assert(0);
    }

    logger.Error("Leaking unresolved type! ", to!string(t), to!string(typeid(t)));

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

    // only generate the bb0 params block
    // if we have params on this function
    if (func.params.length > 0) {
      curr_func.push_block();

      // alloc all the params
      foreach (p; func.params.byValue()) {
        curr_func.add_alloc(new Alloc(get_type(p.type), p.twine.lexeme));
      }
    }

    if (func.func_body !is null) {
      build_block(func.func_body);      
    }

    // if there are no instructions in the last basic
    // block add a return
    // OR if the last instruction is not a return!
    if (curr_func.curr_block.instructions.length == 0 
        || !cast(Return) curr_func.last_instr()) {
      curr_func.add_instr(new Return(new Void_Type()));
    }
  }

  // i feel like this is all completely shit and
  // probably wont work. do this properly! but for now
  // it works for most of the test cases?
  Value build_binary_expr(ast.Binary_Expression_Node binary) {
    Value left = build_expr(binary.left);
    Value right = build_expr(binary.right);
    auto expr = new BinaryOp(left.get_type(), binary.operand, left, right);

    // create a store if we're dealing with an assignment
    if (binary.operand.lexeme == "=") {
      return new Store(left.get_type(), left, right);
    }

    auto temp = new Alloc(left.get_type(), gen_temp());
    curr_func.add_instr(temp);

    auto store = new Store(left.get_type(), temp, expr);
    curr_func.add_instr(store);
    return new Identifier(temp.get_type(), temp.name);
  }

  Value build_path(ast.Path_Expression_Node path) {
    if (path.values.length == 1) {
      return build_expr(path.values[0]);
    }

    foreach (v; path.values) {
      writeln(v);
    }

    assert(0);
  }

  Value build_index_expr(ast.Index_Expression_Node node) {
    Value addr = build_expr(node.array);
    Value sub = build_expr(node.index);
    return new Index(addr.get_type(), addr, sub);
  }

  Value value_at(ast.Expression_Node e) {
    return new Deref(build_expr(e));
  }

  Value addr_of(ast.Expression_Node e) {
    return new AddrOf(build_expr(e));
  }

  Value build_unary_expr(ast.Unary_Expression_Node unary) {
    // grammar.d
    // "+", "-", "!", "^", "@", "&"
    final switch (unary.operand.lexeme) {
    case "+":
    case "-":
    case "!":
    case "^":
      return new UnaryOp(unary.operand, build_expr(unary.value));
    case "@":
      return value_at(unary.value);
    case "&":
      return addr_of(unary.value);
    }
    assert(0);
  }

  Value build_call(ast.Call_Node call) {
    Value left = build_expr(call.left);
    Value[] args;
    foreach (arg; call.args) {
      args ~= build_expr(arg);
    }
    return new Call(left.get_type(), left, args);
  }

  Value build_expr(ast.Expression_Node expr) {
    if (auto integer_const = cast(Integer_Constant_Node) expr) {
      // FIXME
      return new Constant(get_int(32), integer_const);
    }
    else if (auto float_const = cast(Float_Constant_Node) expr) {
      // FIXME
      return new Constant(get_float(64), float_const);
    } 
    else if (auto rune_const = cast(Rune_Constant_Node) expr) {
      // runes are a 4 byte signed integer.
      return new Constant(get_int(32), rune_const);
    } 
    else if (auto index = cast(Index_Expression_Node) expr) {
      return build_index_expr(index);
    } 
    else if (auto binary = cast(Binary_Expression_Node) expr) {
      return build_binary_expr(binary);
    } 
    else if (auto path = cast(Path_Expression_Node) expr) {
      return build_path(path);
    } 
    else if (auto sym = cast(Symbol_Node) expr) {
      return new Identifier(get_type(sym), sym.value.lexeme);
    } 
    else if (auto call = cast(Call_Node) expr) {
      return build_call(call);
    }
    else if (auto unary = cast(Unary_Expression_Node) expr) {
      return build_unary_expr(unary);
    }
    else {
      logger.Fatal("unhandled build_expr in ssa ", to!string(expr), " -> ", to!string(typeid(expr)));
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

    // jump must be the last instruction in it's block!
    // so we need to push a basic block here.
    curr_func.push_block();
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

  void analyze_while_node(ast.While_Statement_Node loop) {
    Value v = build_expr(loop.condition);

    If jmp = new If(v);
    curr_func.add_instr(jmp);

    auto loop_body = build_block(loop.block);
    jmp.a = loop_body;

    jmp.b = new Label(curr_func.push_block());
  }

  override void visit_stat(ast.Statement_Node node) {
    if (auto let = cast(ast.Variable_Statement_Node) node) {
      analyze_let_node(let);
    } 
    else if (auto ret = cast(ast.Return_Statement_Node) node) {
      analyze_return_node(ret);
    } 
    else if (auto if_stat = cast(ast.If_Statement_Node) node) {
      analyze_if_node(if_stat);
    } 
    else if (auto loop = cast(ast.Loop_Statement_Node) node) {
      analyze_loop_node(loop);
    } 
    else if (auto loop = cast(ast.While_Statement_Node) node) {
      analyze_while_node(loop);
    } 
    else if (auto b = cast(ast.Break_Statement_Node) node) {
      analyze_break_node(b);
    } 
    else if (auto e = cast(ast.Expression_Node) node) {
      auto v = build_expr(e);
      if (auto instr = cast(Instruction) v) {
        curr_func.add_instr(instr);
      }
    } 
    else {
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