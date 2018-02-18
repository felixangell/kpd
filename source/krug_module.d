module krug_module;

import std.file;
import std.algorithm.searching : startsWith;
import std.algorithm.comparison : equal;
import std.conv;
import std.path;
import std.string;

import containers.hashset;
import ast;
import sema.symbol;

import err_logger;
import lex.lexer;

enum Token_Type {
  Identifier,
  Floating_Point_Literal,
  Integer_Literal,
  String,
  Rune,
  Symbol,
  Discard,
  Keyword,
  EOF,
};

class Location {
  uint idx, row, col;

  this(uint idx, uint row, uint col) {
    this.idx = idx;
    this.row = row;
    this.col = col;
  }

  override string toString() const {
    return to!string(row) ~ ":" ~ to!string(col);
  }
};

class Span {
  Location start, end;
  ulong index;

  this(Location start, Location end, ulong index) {
    this.start = start;
    this.end = end;
    this.index = index;
  }

  override string toString() const {
    return to!string(start) ~ " - " ~ to!string(end);
  }
};

class Token {
  Source_File* parent;
  string lexeme;
  Token_Type type;
  Span position;

  this(string lexeme, Token_Type type) {
    this.lexeme = lexeme;
    this.type = type;
  }

  bool cmp(string lexeme) {
    return this.lexeme.equal(lexeme);
  }

  bool cmp(Token_Type type) {
    return this.type == type;
  }

  override string toString() const {
    return lexeme ~ ", " ~ to!string(type) ~ " @ " ~ to!string(position);
  }
}

alias Token_Stream = Token[];

// module is like a SOA for sub modules
class Module {
  string path, name;
  HashSet!string file_cache;

  // this looks messy but modules are
  // structured as SOA

  // frontend generated data structure
  // things which are analzed.
  Source_File[string] source_files;
  Token_Stream[string] token_streams;
  AST[string] as_trees;

  // other modules that this module includes
  Module[string] edges;

  // the root symbol table for the submodule
  Symbol_Table[string] sym_tables;

  // for tarjans scc
  int index = -1, low_link = -1;

  this() {
    this.path = "";
    this.name = "main";
  }

  this(string path) {
    this.path = path;
    this.name = std.path.baseName(path);
    this.file_cache = list_dir(path);
  }

  size_t dep_count() {
    size_t num_deps = 0;
    foreach (edge; edges) {
      num_deps += edge.dep_count();
    }
    return num_deps + edges.length;
  }

  bool sub_module_exists(string name) {
    assert(name.cmp("main") && "can't check for sub-modules in main module");

    // check that the sub-module exists, it's
    // easier to append the krug extension on at this point
    return file_cache.contains(name ~ ".krug");
  }

  Source_File load_source_file(string name) {
    assert(name.cmp("main") && "can't load sub-modules in main module");

    const string source_file_path = this.path ~ std.path.dirSeparator ~ name ~ ".krug";
    auto source_file = new Source_File(source_file_path);
    source_files[name] = source_file;
    return source_file;
  }
}

// lists file and directories
HashSet!string list_dir(string pathname) {
  HashSet!string dirs = HashSet!string();
  foreach (file; std.file.dirEntries(pathname, SpanMode.shallow)) {
    if (file.isFile || file.isDir) {
      dirs.insert(std.path.baseName(file.name));
    }
  }
  return dirs;
}

class Source_File {
  string path;
  string contents;

  this(string path) {
    this.path = path;
    this.contents = readText(path);
  }
}
