module sema.decl;

import std.stdio;
import std.conv;

import err_logger;
import ast;
import sema.analyzer : Semantic_Pass, Semantic_Module, AST;
import sema.visitor;

/// this pass will go through all declarations in the module
/// and declare/register them. in addition to this it will
/// build a virtualized scope, each declaration is local to its
/// scope
class Declaration_Pass : Top_Level_Node_Visitor, Semantic_Pass {
    this() {}

    override void analyze_named_type_node(ref ast.Named_Type_Node node) {
        writeln("analyzing " ~ node.twine.lexeme);
    }

    override void analyze_function_node(ref ast.Function_Node) {
		writeln("analyzing function like!");
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