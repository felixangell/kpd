module sema.analyzer;

import std.conv;

import ast;
import logger;
import krug_module;
import tok;

import sema.visitor;
import sema.decl;
import sema.method_decl;
import sema.name_resolve;
import sema.top_level_type_decl;
import sema.mutability;
import sema.type_infer_pass;
import sema.symbol;

import dep_graph;

interface Semantic_Pass {
	void execute(ref Module mod, string sub_mod_name, AST as_tree);
}

// the passes to run on
// the semantic modules in order
Semantic_Pass[] passes = [
	// the declaration pass declares that symbols
	// exist in their respective scopes. this has to be
	// done first so that all the subsequent passes
	// know what symbols exist and where.
	new Declaration_Pass, 

	// methods are then declared, this cannot be done
	// during the declaration pass because we need to know
	// what symbols have been declared to link a method
	// (its func receiver)
	// consider
	// 
	// func (f *Foo) 
	//         ^^^^ what symbol is Foo? this might have been
	// 
	// defined later on in a file and since these declarations
	// are done in a linear sequence from top to bottom
	// we might not know what Foo is.
	new Method_Declaration_Pass,

	// the name resolve pass looks for all the symbols that
	// have been referenced in expressions. now that we have
	// declared all symbols i.e. types, variables, methods, 
	// we can resolve them and make sure that they all exist.
	new Name_Resolve_Pass,

	// this pass will _introduce types_ into their respective
	// type environments. this is _not_ symbols, but literal types
	// in the type environment are created here. this pass only
	// introduces _top level types_ i.e. named types and aliases
	// for a similar reason we declare first before we do method
	// declaration. when inferring types we want to know all of
	// the types that exist first (in an order independent fashion)
	new Top_Level_Type_Decl_Pass,

	// the type infer pass will look at expressions and infer
	// their types from their values. it performs a simple type
	// unification, which gives us some simple type checks to
	// ensure types are the same for things like binary expressions.
	// this also handles type checking on trivial things like
	// for loops, while loops, if statements, else if statements,
	// etc. to ensure that their conditions are boolean types.
	new Type_Infer_Pass,

	// the mutability pass will check re-assignments and resolve
	// their symbols to see if the symbol it references is mutable
	// i.e. if it can be mutated or not.
	new Mutability_Pass,

	// TODO type checking!

	// TODO use before define? 

	// TODO accessability checks
	// - this pass might be possible
	// during name resolution.

	// TODO loops that dont terminate?

	// TODO unused variables
	// TODO unused functions
	// TODO unused exported symbols

	// TODO unreachable/dead code
];

void log(Semantic_Pass pass, Log_Level level, string[] msg...) {
	logger.log(level, (to!string(pass) ~ ": ") ~ msg);
}

void log(Semantic_Pass pass, Log_Level level, Token_Info tok, string[] msg...) {
	logger.log(level, (to!string(pass) ~ ": ") ~ msg ~ "\n" ~ logger.blame_token(tok));
}

struct Semantic_Analysis {
	Dependency_Graph graph;

	this(ref Dependency_Graph graph) {
		this.graph = graph;
	}

	void process(ref Module mod) {
		foreach (ref idx, pass; passes) {
			logger.verbose("  * " ~ to!string(pass));
	
			foreach (ref sub_mod_name, as_tree; mod.as_trees) {
				logger.verbose("- " ~ mod.name ~ "::" ~ sub_mod_name);

				// FIXME this really shows how sloppy
				// the architecture is for this... we're
				// assuming here the visitors are all 
				// top level node visitors.
				(cast(Top_Level_Node_Visitor)pass).setup_sym_table(mod, sub_mod_name, as_tree);

				pass.execute(mod, sub_mod_name, as_tree);
			}

			// don't continue doing passes if we 
			// encounter some errors. the passes
			// depend on eachother so we probably
			// wont get very far.
			const sema_errors = logger.get_err_count();
			if (sema_errors > 0) {
				return;
			}
		}
	}
}
