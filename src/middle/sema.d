module sema.analyzer;

import std.conv;

import ast;
import logger;
import krug_module;

import sema.visitor;
import sema.decl;
import sema.name_resolve;
import sema.top_level_type_decl;
import sema.type_infer_pass;
import sema.symbol;

import dependency_scanner;

interface Semantic_Pass {
	void execute(ref Module mod, AST as_tree);
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

	void process(ref Module mod, AST as_tree) {
		foreach (pass; passes) {
			logger.Verbose("  * " ~ to!string(pass));

			// FIXME this really shows how sloppy
			// the architecture is for this... we're
			// assuming here the visitors are all 
			// top level node visitors.
			(cast(Top_Level_Node_Visitor)pass).setup_sym_table(as_tree);

			pass.execute(mod, as_tree);
		}
	}
}
