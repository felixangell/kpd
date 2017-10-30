module sema.decl;

import std.stdio;
import std.conv;

import err_logger;
import ast;
import sema.analyzer : Semantic_Pass, Semantic_Module, AST;

class Declaration_Pass : Semantic_Pass {
    this() {}

    override void execute(ref Semantic_Module mod, ref AST as_tree) {
        foreach (node; as_tree) {
            if (auto named_type_node = cast(ast.Named_Type_Node) node) {

            } else if (auto func_node = cast(ast.Function_Node) node) {

            }
        }
    }

    override string toString() const {
        return "decl-pass";
    }
}