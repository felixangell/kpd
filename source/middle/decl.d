module sema.decl;

import std.stdio;
import std.conv;

import err_logger;
import colour;
import ast;
import sema.analyzer : Semantic_Pass;
import sema.range;
import sema.symbol;
import sema.visitor;
import krug_module;

/// this pass will go through all declarations in the module
/// and declare/register them. in addition to this it will
/// build a virtualized scope, each declaration is local to its
/// scope
class Declaration_Pass : Top_Level_Node_Visitor, Semantic_Pass {
	Scope current;

    override void analyze_named_type_node(ast.Named_Type_Node node) {
        auto existing = current.register_sym(new Symbol(node, node.twine));
        if (existing !is null) {
            err_logger.Error([
                "Named type '" ~ colour.Bold(node.twine.lexeme) ~ "' defined here:",
                Blame_Token(node.twine),
                "Conflicts with symbol defined here:",
                Blame_Token(existing.tok),
            ]);
        }
    }

    override void analyze_function_node(ast.Function_Node node) {
        if (current is null) {
            err_logger.Fatal("no scope pushed for " ~ Blame_Token(node.name));
            return;
        }

        auto existing = current.register_sym(new Symbol(node, node.name));
        if (existing !is null) {
            err_logger.Error([
                "Function '" ~ colour.Bold(node.name.lexeme) ~ "' defined here:",
                Blame_Token(node.name),
                "Conflicts with symbol defined here:",
                Blame_Token(existing.tok),
            ]);
        }

        // some functions have no body!
        // these are prototype functions
        if (node.func_body !is null) {
    		visit_block(node.func_body);
        }

        foreach (param_entry; node.params.byKeyValue()) {
            auto param = param_entry.value;
            // we don't have to check for conflicts here because
            // this HAS to be done during the parsing stage!
            current.register_sym(new Symbol(param, param.twine.lexeme));
        }

        // TODO check that the function receiver
        // is a valid symbol

        // TODO store a ptr to this method
        // in the Structure it's a member of.
        // if func recvr exists.

        // only pop the scope if the function has
        // a definition. otherwise we wont have
        // a scope pushed and we'll be popping the parent
        // scope which is likely the only scope we have
        // which would cause a seg fault!
        if (node.func_body !is null) {
            pop_scope();            
        }
    }

    void visit_block(ast.Block_Node block) {
        if (block.range is null) {
            block.range = push_scope();
        }
        current = block.range;

        foreach (stat; block.statements) {
            if (auto var = cast(Variable_Statement_Node) stat) {
                analyze_let_node(var);
            }
        }
    }

    override void analyze_let_node(ast.Variable_Statement_Node node) {
        auto existing = current.register_sym(new Symbol(node, node.twine));
        if (existing !is null) {
            err_logger.Error([
                "Variable '" ~ colour.Bold(node.twine.lexeme) ~ "' defined here:",
                Blame_Token(node.twine),
                "Conflicts with symbol defined here: ",
                // Blame_Token(existing),
            ]);
        }
    }

    override void execute(ref Module mod, string sub_mod_name) {       
        assert(mod !is null);

        if (sub_mod_name !in mod.as_trees) {
        	err_logger.Error("couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
			return;
        }

        // push the global scope for this sub-module.
        // this global scope contains all of the top
        // level declarations: named types, functions, ...
        // this scope is stored for the sub-module we're working with
        auto new_scope = push_scope();
        mod.scopes[sub_mod_name] = new_scope;

        {
            auto ast = mod.as_trees[sub_mod_name];
            foreach (node; ast) {
                if (node !is null) {
                    super.process_node(node);
                }
            }
        }

        pop_scope();
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

    override string toString() const {
        return "decl-pass";
    }
}