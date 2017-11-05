module sema.decl;

import std.stdio;
import std.conv;

import err_logger;
import colour;
import ast;
import sema.analyzer : Semantic_Pass;
import sema.visitor;
import sema.range;
import krug_module;

/// this pass will go through all declarations in the module
/// and declare/register them. in addition to this it will
/// build a virtualized scope, each declaration is local to its
/// scope
class Declaration_Pass : Top_Level_Node_Visitor, Semantic_Pass {
	Scope current;

    this() {
		this.current = new Scope;    
    }

    override void analyze_named_type_node(ast.Named_Type_Node node) {
        auto existing = current.register_sym(new Symbol(node, node.twine));
        if (existing !is null) {
            err_logger.Error([
                "Named type '" ~ colour.Bold(node.twine.lexeme) ~ "' defined here:",
                Blame_Token(node.twine),
                "Conflicts with symbol defined here: ",
                // Blame_Token(existing),
            ]);
        }
    }

    override void analyze_function_node(ast.Function_Node node) {
        auto existing = current.register_sym(new Symbol(node, node.name));
        if (existing !is null) {
            err_logger.Error([
                "Function '" ~ colour.Bold(node.name.lexeme) ~ "' defined here:",
                Blame_Token(node.name),
                "Conflicts with symbol defined here: ",
                // Blame_Token(existing),
            ]);
        }

        // some functions have no body!
        // these are prototype functions
        if (node.func_body !is null) {
    		visit_block(node.func_body);
        }
    }

    override void execute(ref Module mod, string sub_mod_name) {       
        assert(mod !is null);

        if (sub_mod_name !in mod.as_trees) {
        	err_logger.Error("couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
			return;
        }

        auto ast = mod.as_trees[sub_mod_name];
        foreach (node; ast) {
            if (node !is null) {
                super.process_node(node);
            }
        }
    }

    Scope push_scope() {
        auto s = new Scope(current);
        current = s;
        return s;
    }

    Scope pop_scope() {
        auto old = current;
        current = current.outer;
        return old;
    }

    void visit_block(ast.Block_Node block) {
        if (block.range is null) {
            block.range = push_scope();
        }
        current = block.range;
    }

    override string toString() const {
        return "decl-pass";
    }
}