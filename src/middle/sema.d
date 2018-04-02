module sema.analyzer;

import std.conv;

import ast;
import logger;
import krug_module;

import sema.decl;
import sema.name_resolve;
import sema.top_level_type_decl;
import sema.type_infer_pass;

import dependency_scanner;

interface Semantic_Pass {
	void execute(ref Module mod, string sub_mod_name);
}

// the passes to run on
// the semantic modules in order
Semantic_Pass[] passes = [
	new Declaration_Pass, 
	new Name_Resolve_Pass,

	// declare the types in the top level.
	new Top_Level_Type_Decl_Pass,

	// infer the types
	// some simple type checks are
	// done here..!
	new Type_Infer_Pass,

	// type checking!
];

void log(Semantic_Pass pass, Log_Level level, string[] msg...) {
	logger.Log(level, (to!string(pass) ~ ": ") ~ msg);
}

struct Semantic_Analysis {
	Dependency_Graph graph;

	this(ref Dependency_Graph graph) {
		this.graph = graph;
	}

	void process(ref Module mod, string sub_mod_name) {
		logger.Verbose("- " ~ mod.name ~ "::" ~ sub_mod_name);
		foreach (pass; passes) {
			logger.Verbose("  * " ~ to!string(pass));
			pass.execute(mod, sub_mod_name);
		}
	}
}
