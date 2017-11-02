module sema.analyzer;

import std.conv;

import ast;
import sema.decl;
import err_logger;

import dependency_scanner : AST, Module, Dependency_Graph;

/+
    NOTE! we could use the visitor pattern here but i honestly
    think its pretty messy to use so im avoiding it.
+/

struct Semantic_Module {
    AST[string] as_trees;
}

interface Semantic_Pass {
    void execute(ref Semantic_Module mod, ref AST as_tree);
}

// the passes to run on
// the semantic modules in order
Semantic_Pass[] passes = [
    new Declaration_Pass,
];

struct Semantic_Analysis {
    Dependency_Graph graph;
    Semantic_Module mod;

    this(ref Dependency_Graph graph) {
        this.graph = graph;
    }

    void process(ref AST as_tree, string mod_name, string sub_mod_name) {
        mod.as_trees[sub_mod_name] = as_tree;

        err_logger.Verbose("- " ~ mod_name ~ "::" ~ sub_mod_name);
        foreach (pass; passes) {
            err_logger.Verbose("  * " ~ to!string(pass));
            pass.execute(mod, as_tree);
        }
    }
}