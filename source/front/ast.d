module ast;

import std.typecons;
import std.conv;
import std.bigint;

import compiler_error;
import diag.engine;

import logger;
import colour;
import sema.type : Type;
import sema.symbol;
import krug_module;

// binding of an expression to a token
alias Binding = Tuple!(Token, "twine", Expression_Node, "value");

interface Semicolon_Stat {
}

alias AST = ast.Node[];

class Node {
  Type realType;
}

class Statement_Node : Node {
}

// "let" "{" { iden "," } "}" "=" Expr
class Structure_Destructuring_Statement_Node : Statement_Node, Semicolon_Stat {
  Token[] values;
  Expression_Node rhand;
}

// "let" "(" { iden "," } ")" "=" Expr
class Tuple_Destructuring_Statement_Node : Statement_Node, Semicolon_Stat {
  Token[] values;
  Expression_Node rhand;
}

// defer ( stat )
class Defer_Statement_Node : Statement_Node {
  Statement_Node stat;

  this(Statement_Node stat) {
    this.stat = stat;
  }
}

class Loop_Statement_Node : Statement_Node {
  Block_Node block;
  this(Block_Node block) {
    this.block = block;
  }
}

class While_Statement_Node : Statement_Node {
  Expression_Node condition;
  Block_Node block;
  this(Expression_Node condition, Block_Node block) {
    this.condition = condition;
    this.block = block;
  }
}

class If_Statement_Node : Statement_Node {
  Expression_Node condition;
  Block_Node block;
  this(Expression_Node condition, Block_Node block) {
    this.condition = condition;
    this.block = block;
  }
}

class Else_If_Statement_Node : Statement_Node {
  Expression_Node condition;
  Block_Node block;
  this(Expression_Node condition, Block_Node block) {
    this.condition = condition;
    this.block = block;
  }
}

class Else_Statement_Node : Statement_Node {
  Block_Node block;
  this(Block_Node block) {
    this.block = block;
  }
}

// return [ expr ] ";"
class Return_Statement_Node : Statement_Node, Semicolon_Stat {
  Expression_Node value;

  this(Expression_Node value) {
    this.value = value;
  }
}

// break ";"
class Break_Statement_Node : Statement_Node, Semicolon_Stat {
}

// next ";"
class Next_Statement_Node : Statement_Node, Semicolon_Stat {
}

// yield Expression ";"
class Yield_Statement_Node : Statement_Node, Semicolon_Stat {
  Expression_Node value;

  this(Expression_Node value) {
    this.value = value;
  }
}

// "type" Identifier Type ";"
class Named_Type_Node : Statement_Node, Semicolon_Stat {
  Token twine;

  Type_Node type;

  this(Token twine, Type_Node type) {
    this.twine = twine;
    this.type = type;
  }
}

// let name [ Type ] [ "=" Expression ] ";"
class Variable_Statement_Node : Statement_Node, Semicolon_Stat {
  Token twine;
  Type_Node type;
  Expression_Node value = null;
  bool mutable = false;

  this(Token twine, Type_Node type, bool mutable = false) {
    this.twine = twine;
    this.type = type;
    this.mutable = mutable;
  }
}

// CONSTANTS

class Constant_Node(T) : Expression_Node {
  Token tok;
  T value;

  this(Token tok, T value) {
    this.tok = tok;
    this.value = value;
  }
}

class String_Constant_Node : Constant_Node!string {
  this(Token tok) {
    super(tok, tok.lexeme);
  }
}

class Float_Constant_Node : Constant_Node!double {
  this(Token tok) {
    super(tok, to!double(tok.lexeme));
  }
}

class Integer_Constant_Node : Constant_Node!BigInt {
  this(Token tok) {
    super(tok, BigInt(tok.lexeme));
  }
}

class Boolean_Constant_Node : Constant_Node!bool {
  this(Token tok) {
    // TODO: what if token is something other
    // than "true"? this has to be validated before
    // we create the node.
    super(tok, tok.cmp("true") ? true : false);
  }
}

class Rune_Constant_Node : Constant_Node!dchar {
  this(Token tok) {
    super(tok, to!dchar(tok.lexeme[0]));
  }
}

// TOP LEVEL DECLARATION AST NODES

class Function_Node : Node {
  Token name;
  Type_Node return_type;
  Block_Node func_body;
  Variable_Statement_Node func_recv;
  Function_Parameter[string] params;

  Generic_Sigil[] generics;
}

class Block_Node : Statement_Node {
  Statement_Node[] statements;
  Function_Node parent;
  Symbol_Table sym_table;

  this() {

  }
}

// EXPRESSION AST NODES

class Expression_Node : Statement_Node {
  Symbol_Value resolved_symbol = null;
}

class Call_Node : Expression_Node {
  Expression_Node left;
  Expression_Node[] args;

  // some_foo!int();
  // some_other!(int, double, Foo)();
  // some_blah!(int)();
  ast.Type_Path_Node[] generic_params;

  this(Expression_Node left) {
    this.left = left;
  }

  override string toString() {
    string arguments;
    foreach (i, a; args) {
      if (i > 0) arguments ~= ",";
      arguments ~= to!string(a);
    }
    return to!string(left) ~ "(" ~ arguments ~ ")";
  }
}

class Symbol_Node : Expression_Node {
  Token value;

  this(Token value) {
    this.value = value;
  }

  override string toString() const {
    return "sym(" ~ value.lexeme ~ ")";
  }
}

class Path_Expression_Node : Expression_Node {
  Expression_Node[] values;

  // the table in which the path was
  // resolved to.
  Symbol_Table resolved_to = null;

  override string toString() {
    string res;
    foreach (idx, v; values) {
      if (idx > 0) res ~= ".";
      res ~= to!string(v);
    }
    return "path(" ~ res ~ ")";
  }
}

class Slice_Expression_Node : Expression_Node {
  Expression_Node start, end;

  this(Expression_Node start, Expression_Node end) {
    this.start = start;
  }
}

class Index_Expression_Node : Expression_Node {
  Expression_Node array, index;

  this(Expression_Node array, Expression_Node index) {
    this.array = array;
    this.index = index;
  }

  override string toString() {
    return to!string(array) ~ "[" ~ to!string(index) ~ "]";
  }
}

class Lambda_Node : Expression_Node {
  Function_Type_Node func_type;
  Block_Node block;

  this(Function_Type_Node func_type, Block_Node block) {
    this.func_type = func_type;
    this.block = block;
  }
}

class Block_Expression_Node : Expression_Node {
  Block_Node block;

  this(Block_Node block) {
    this.block = block;
  }
}

class Binary_Expression_Node : Expression_Node {
  Expression_Node left, right;
  Token operand;

  this(Expression_Node left, Token operator, Expression_Node right) {
    this.left = left;
    this.operand = operator;
    this.right = right;
  }

  override string toString() {
    return to!string(left)~operand.lexeme ~ to!string(right);
  }
}

class Unary_Expression_Node : Expression_Node {
  Token operand;
  Expression_Node value;

  this(Token operand, Expression_Node value) {
    this.operand = operand;
    this.value = value;
  }

  override string toString() {
    return operand.lexeme ~ to!string(value);
  }
}

class Paren_Expression_Node : Expression_Node {
  Expression_Node value;

  this(Expression_Node value) {
    this.value = value;
  }

  override string toString() {
    return "(" ~ to!string(value) ~ ")";
  }
}

// TYPE AST NODES

class Type_Node : Node {
}

class Resolved_Type : Type_Node {
  // a copy of the node itself before
  // we resolved it.
  Type_Node before;

  // the real type
  Type type;

  this(Type_Node before, Type type) {
    this.before = before;
    this.type = type;
  }
}

class Primitive_Type_Node : Type_Node {
  Token type_name;

  this(Token type_name) {
    this.type_name = type_name;
  }
}

// complex types

class Type_Path_Node : Type_Node {
  Token[] values;
}

class Tuple_Type_Node : Type_Node {
  Type_Node[] types;
}

class Array_Type_Node : Type_Node {
public:
  Type_Node base_type;
  Expression_Node value;

  this(Type_Node base_type, Expression_Node value = null) {
    this.base_type = base_type;
    this.value = value;
  }
}

class Slice_Type_Node : Type_Node {
public:
  Type_Node base_type;

  this(Type_Node base_type) {
    this.base_type = base_type;
  }
}

class Pointer_Type_Node : Type_Node {
public:
  Type_Node base_type;

  this(Type_Node base_type) {
    this.base_type = base_type;
  }
}

class Union_Field : Node {
  Token name;
  Type_Node type;

  this(Token name, Type_Node type) {
    this.name = name;
    this.type = type;
  }
};

class Union_Type_Node : Type_Node {
public:
  Union_Field[string] fields;

  void add_field(Token name, Type_Node type) {
    fields[name.lexeme] = new Union_Field(name, type);
  }
}

class Structure_Field : Node {
  Token name;
  Type_Node type;
  Expression_Node value;

  this(Token name, Type_Node type, Expression_Node value = null) {
    this.name = name;
    this.type = type;
    this.value = value;
  }
};

class Structure_Type_Node : Type_Node {
public:
  Structure_Field[string] fields;

  void add_field(Token name, Type_Node type, Expression_Node value = null) {
    if (name.lexeme in fields) {
      Diagnostic_Engine.throw_error(compiler_error.SYMBOL_CONFLICT, name,
          fields[name.lexeme].name);
    } else {
      fields[name.lexeme] = new Structure_Field(name, type, value);
    }
  }
}

class Function_Parameter : Node {
  bool mutable;
  Token twine;
  Type_Node type;

  this(bool mutable, Token twine, Type_Node type) {
    this.mutable = mutable;
    this.twine = twine;
    this.type = type;
  }
}

class Function_Type_Node : Type_Node {
public:
  Type_Node return_type;
  Function_Parameter[string] params;

  // make this just one receiver param
  Function_Parameter[string] recv_params;

  void add_recv_param(Token twine, Type_Node type, bool mutable = false) {
    recv_params[twine.lexeme] = new Function_Parameter(mutable, twine, type);
  }

  void add_param(Token twine, Type_Node type, bool mutable = false) {
    params[twine.lexeme] = new Function_Parameter(mutable, twine, type);
  }
}

alias Trait_Attribute = Tuple!(Token, "twine", Function_Type_Node, "type");

class Trait_Type_Node : Type_Node {
public:
  Trait_Attribute[string] attributes;

  void add_attrib(Token name, Function_Type_Node func_type_node) {
    attributes[name.lexeme] = Trait_Attribute(name, func_type_node);
  }
}

// TODO tagged union node

// GENERIC STUFF

struct Generic_Sigil {
  Token name;
  Type_Path_Node[] restrictions;
}

// i dont think order matters here,
// associative arrays dont preserve order
alias Generic_Set = Generic_Sigil[string];
