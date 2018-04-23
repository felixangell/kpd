module krug_module;

import std.file;
import std.algorithm.searching : startsWith;
import std.conv;
import std.path;
import std.string;

import ast;
import tok;
import sema.symbol;

import logger;
import lex.lexer;
import kir.ir_mod;

alias Token_Stream = Token[];

class Module {
	string name;

	Source_File[string] source_files;

	// frontend generated data structure
	// things which are analzed.
	Token_Stream[string] token_streams;
	AST[string] as_trees;

	// the root symbol table for the module
	Symbol_Table sym_tables;

	IR_Module ir_mod;

	// other modules that this module includes
	Module[string] edges;

	// for tarjans scc
	int index = -1, low_link = -1;

	this(string name) {
		this.name = name;
	}

	size_t dep_count() {
		size_t num_deps = 0;
		foreach (edge; edges) {
			num_deps += edge.dep_count();
		}
		return num_deps + edges.length;
	}
}

// lists file and directories
bool[string] list_dir(string pathname) {
	bool[string] dirs;
	foreach (file; std.file.dirEntries(pathname, SpanMode.shallow)) {
		if (file.isFile || file.isDir) {
			dirs[std.path.baseName(file.name)] = true;
		}
	}
	return dirs;
}

class Source_File {
	string path;
	string contents;

	this(string path) {
		this.path = path;
		try {
			this.contents = readText(path);		
		} 
		catch (FileException e) {
			logger.fatal("failed to read file '", to!string(path), "'");
		}
	}
}
