module back.code_gen;

import std.stdio;
import std.conv;

import ast;
import err_logger;
import krug_module;

import dependency_scanner;
import exec.instruction;

// credit to Adam D. Ruppe
// http://forum.dlang.org/thread/gyfofjdfzjzmkbsygqsf@forum.dlang.org
T instanceof(T)(Object o) if (is(T == class)) {
  return cast(T) o;
}

struct Code_Generator {
  Dependency_Graph graph;

  uint program_index = 0;
  Instruction[] program;

  uint[string] func_addr_reg;

  this(ref Dependency_Graph graph) {
    this.graph = graph;
  }

  uint emit(Instruction instr) {
    auto idx = program_index++;
    program ~= instr;
    return idx;
  }

  void rewrite(uint index, Instruction instr) {
    program[index] = instr;
  }

  void gen_func(ast.Function_Node func) {
    immutable string func_name = func.name.lexeme;

    uint func_addr = program_index;
    func_addr_reg[func_name] = func_addr;
    err_logger.Verbose("func '", to!string(func_name), "' at addr: ", to!string(func_addr));

    emit(encode(OP.ENTR));

    if (func.func_body !is null) {
      gen_block(func.func_body);
    }

    emit(encode(OP.RET));
  }

  uint get_ea(ast.Expression_Node e) {
    if (auto sym = e.instanceof!(ast.Symbol_Node)) {
      return addr_table[sym.value.lexeme];
    }

    if (e.instanceof!(ast.Path_Expression_Node)) {
      return get_ea((cast(ast.Path_Expression_Node) e).values[0]);
    }

    // hacky.?
    if (auto unary = e.instanceof!(ast.Unary_Expression_Node)) {
      return get_ea(unary.value);
    }

    err_logger.Fatal("Couldn't get addr for expression " ~ to!string(e));
    assert(0);
  }

  // left = right
  void gen_store(ast.Binary_Expression_Node binary) {
    uint addr = get_ea(binary.left);
    gen_expr(binary.right);
    emit(encode(OP.STRI, addr));
  }

  // TODO: for generating expressions
  // we need type information so we know whethejr
  // to emit byte, short, integer, long, etc.
  // as well as how is signed-ness going to be handled?

  void gen_binary_expr(ast.Binary_Expression_Node binary) {
    if (binary.operand.lexeme == "=") {
      gen_store(binary);
      return;
    }

    gen_expr(binary.left);
    gen_expr(binary.right);

    // handle the operation
    auto operator = binary.operand.lexeme;
    switch (operator) {
    case "==":
      emit(encode(OP.CMPI));
      break;
    case "&&":
      emit(encode(OP.AND));
      break;
    case "||":
      emit(encode(OP.OR));
      break;
    case ">":
      emit(encode(OP.GTRI));
      break;

      // simple arithmetic operations
    case "-":
      emit(encode(OP.SUBI));
      break;
    case "+":
      emit(encode(OP.ADDI));
      break;
    case "*":
      emit(encode(OP.MULI));
      break;
    case "/":
      emit(encode(OP.DIVI));
      break;

    default:
      err_logger.Fatal("unhandled operator in gen_binary_expr " ~ operator);
      break;
    }
  }

  // (sym x) (binary (. y ?))
  void gen_path_expr(ast.Path_Expression_Node path) {
    auto fst = path.values[0];
    if (auto sym = fst.instanceof!(ast.Symbol_Node)) {
      const auto name = sym.value.lexeme;
      assert(name in addr_table);
      emit(encode(OP.LDI, addr_table[name]));
    }

    // TODO: handle me!
  }

  void gen_unary_expr(ast.Unary_Expression_Node unary) {
    switch (unary.operand.lexeme) {
    case "@":
      auto addr = get_ea(unary.value);
      emit(encode(OP.LEA, addr));
      return;
    case "&":
      auto addr = get_ea(unary.value);
      emit(encode(OP.PSHI, addr));
      return;
    default:
      break;
    }

    err_logger.Fatal("unhandled unary " ~ to!string(unary.operand));
  }

  void gen_expr(ast.Expression_Node expr) {
    if (auto binary = cast(ast.Binary_Expression_Node) expr) {
      gen_binary_expr(binary);
    } else if (auto unary = cast(ast.Unary_Expression_Node) expr) {
      gen_unary_expr(unary);
    } else if (auto integer = cast(ast.Integer_Constant_Node) expr) {
      // TODO handle types here.
      emit(encode(OP.PSHI, integer.value.to!int));
    } else if (auto path = cast(ast.Path_Expression_Node) expr) {
      gen_path_expr(path);
    } else {
      err_logger.Fatal("unhandled expr " ~ to!string(expr));
    }
  }

  void gen_if_stat(ast.If_Statement_Node if_stat) {
    gen_expr(if_stat.condition);

    // the if must be a boolean expression
    // after the evaluation if the value is a 
    // 0 then we jump to the end of the address
    // skipping the body of the if statement
    uint jne_instr_addr = emit(encode(OP.JNE, 0));

    gen_block(if_stat.block);
    uint if_end_addr = program_index;

    // rewrite the instruction so that
    // our address is correct
    // TODO: find a nicer way to approach this.
    rewrite(jne_instr_addr, encode(OP.JNE, if_end_addr));
  }

  void gen_call_node(ast.Call_Node call_node) {
    // todo some kind of magical load thing?
    // for now we hack this in so module load stuff
    // doesn't work 
    if (auto path = call_node.left.instanceof!(ast.Path_Expression_Node)) {
      auto fst = cast(ast.Symbol_Node) path.values[0];

      // HACK
      const string name = to!string(fst.value.lexeme);
      if (name !in func_addr_reg) {
        err_logger.Fatal("No such function " ~ name ~ " registered");
      }

      uint addr = func_addr_reg[name];
      err_logger.Verbose("emitting func call to ", name, " @addr: ", to!string(addr));
      emit(encode(OP.CALL, addr));
    }
  }

  void gen_loop_stat(ast.Loop_Statement_Node loop) {
    uint loop_start = program_index;
    gen_block(loop.block);
    emit(encode(OP.GOTO, loop_start));
  }

  void gen_while_loop(ast.While_Statement_Node while_loop) {
    uint loop_start = program_index;
    gen_block(while_loop.block);
    gen_expr(while_loop.condition);
    // if the condition is true, jump
    // back to the loop start.
    emit(encode(OP.JE, loop_start));
  }

  // TODO: this should be per block
  // or we can mangle the names.
  uint local_addr = 0;
  uint[string] addr_table;

  void gen_var_stat(ast.Variable_Statement_Node var) {
    // what do we do if the value doesnt exist? for now
    // assume its zero.

    if (var.value is null) {
      // handle me later.
      return;
    }

    gen_expr(var.value);

    // todo if it's a constant we can store it
    // but instead we have to evaluate it on the stack
    emit(encode(OP.ALLOCI));

    addr_table[var.twine.lexeme] = local_addr;
    local_addr += int.sizeof;
  }

  void gen_stat(ast.Statement_Node stat) {
    if (auto if_stat = stat.instanceof!(ast.If_Statement_Node)) {
      gen_if_stat(if_stat);
    } else if (auto call_node = stat.instanceof!(ast.Call_Node)) {
      gen_call_node(call_node);
    } else if (auto loop_stat = stat.instanceof!(ast.Loop_Statement_Node)) {
      gen_loop_stat(loop_stat);
    } else if (auto while_loop = stat.instanceof!(ast.While_Statement_Node)) {
      gen_while_loop(while_loop);
    } else if (auto var = stat.instanceof!(ast.Variable_Statement_Node)) {
      gen_var_stat(var);
    } else if (auto expr = stat.instanceof!(ast.Expression_Node)) {
      gen_expr(expr);
    } else {
      err_logger.Warn("unhandled statement node " ~ to!string(stat));
    }
  }

  uint gen_block(ast.Block_Node block) {
    uint block_start_addr = program_index;
    foreach (ref stat; block.statements) {
      gen_stat(stat);
    }
    return block_start_addr;
  }

  void gen_named_type(ast.Node node) {
  }

  void gen_node(ast.Node node) {
    if (auto named_type = node.instanceof!(ast.Named_Type_Node)) {
      gen_named_type(named_type);
    } else if (auto func = node.instanceof!(ast.Function_Node)) {
      gen_func(func);
    } else if (auto stat = node.instanceof!(ast.Statement_Node)) {
      gen_stat(stat);
    } else {
      err_logger.Warn("unhandled node ! " ~ to!string(node));
    }
  }

  void process(ref Module mod, string sub_mod_name) {
    err_logger.Verbose("- " ~ mod.name ~ "::" ~ sub_mod_name);

    auto ast = mod.as_trees[sub_mod_name];
    foreach (node; ast) {
      if (node !is null) {
        gen_node(node);
      }
    }
  }
}
