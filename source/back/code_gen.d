module back.code_gen;

import std.stdio;
import std.conv;

import ast;
import err_logger;
import krug_module;

import dependency_scanner;
import exec.instruction;

struct Code_Generator {
    Dependency_Graph graph;

    Instruction[] program;

    uint[string] func_addr;

    this(ref Dependency_Graph graph) {
        this.graph = graph;
    }

    void gen_func(ast.Function_Node func) {
        writeln("generating code for " ~ to!string(func));
    }

    void gen_named_type(ast.Node node) {
        writeln("generated code for a named type!");
    }

    void gen_node(ast.Node node) {
    	if (auto named_type = cast(ast.Named_Type_Node)node) {
    		gen_named_type(named_type);
        } else if (auto func = cast(ast.Function_Node)node) {
            gen_func(func);
        } else {
            writeln("unhandled node ! " ~ to!string(node));
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