module sema.decl;

import std.stdio;
import std.conv;

import err_logger;
import ast;
import sema.analyzer : Semantic_Pass, Semantic_Module, AST;
import sema.visitor;

class Declaration_Pass : Top_Level_Node_Visitor, Semantic_Pass {
    this() {}

    override void analyze_named_type_node(ref ast.Named_Type_Node) {

    }

    override void analyze_function_node(ref ast.Function_Node) {
        
    }

    override void execute(ref Semantic_Module mod, ref AST as_tree) {
        foreach (ref node; as_tree) {
            super.process_node(node);
        }
    }

    override string toString() const {
        return "decl-pass";
    }
}