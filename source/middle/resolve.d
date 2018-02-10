module sema.resolve;

import std.conv;

import ast;
import sema.visitor;
import sema.analyzer : Semantic_Pass;
import sema.range;
import sema.type;
import krug_module;
import err_logger;

// this pass looks over expressions and resolves
// paths, calls, etc.
class Resolve_Pass : Top_Level_Node_Visitor, Semantic_Pass {
	Scope current;

	override void analyze_named_type_node(ast.Named_Type_Node node) {

	}

    override void analyze_let_node(ast.Variable_Statement_Node) {
    	
    }

    override void analyze_function_node(ast.Function_Node node) {
        // some functions have no body!
        // these are prototype functions
        if (node.func_body !is null) {
    		visit_block(node.func_body);
        }

        pop_scope();
    }

    void visit_stat(ast.Statement_Node stat) {
    	err_logger.Warn("resolve: unhandled statement " ~ to!string(stat));
    }

    void visit_block(ast.Block_Node block) {
    	assert(block.range !is null);
        current = block.range;

        foreach (stat; block.statements) {
            if (stat is null) {
                err_logger.Fatal("what? " ~ to!string(block));
            }
            visit_stat(stat);
        }
    }

    Scope pop_scope() {
        auto old = current;
        current = current.outer;
        return old;
    }

	override void execute(ref Module mod, string sub_mod_name) {       
        assert(mod !is null);

        if (sub_mod_name !in mod.as_trees) {
        	err_logger.Error("couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
			return;
        }

        current = mod.scopes[sub_mod_name];

        auto ast = mod.as_trees[sub_mod_name];
        foreach (node; ast) {
            if (node !is null) {
		        super.process_node(node);
            }
        }
    }

    override string toString() const {
        return "resolve-pass";
    }

}