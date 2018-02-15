module sema.analyzer;

import std.conv;

import ast;
import sema.range;
import err_logger;
import krug_module;
import sema.decl;
import sema.type_def;
import sema.type_infer;
import sema.resolve;
import sema.name_resolve;

import dependency_scanner;

interface Semantic_Pass {
    void execute(ref Module mod, string sub_mod_name);
}

// the passes to run on
// the semantic modules in order
Semantic_Pass[] passes = [
    new Declaration_Pass,
    new Name_Resolve_Pass,
    // new Type_Define_Pass,
    // new Type_Infer_Pass,
    // new Resolve_Pass,
];

struct Semantic_Analysis {
    Dependency_Graph graph;

    this(ref Dependency_Graph graph) {
        this.graph = graph;
    }

    void process(ref Module mod, string sub_mod_name) {
        err_logger.Verbose("- " ~ mod.name ~ "::" ~ sub_mod_name);
        foreach (pass; passes) {
            err_logger.Verbose("  * " ~ to!string(pass));
            pass.execute(mod, sub_mod_name);
        }
    }
}