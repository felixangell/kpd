module sema.decl;

import std.stdio;
import std.conv;

import err_logger;
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
        writeln("analyzing " ~ node.twine.lexeme);
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

    override void analyze_function_node(ast.Function_Node node) {
		visit_block(node.func_body);
    }

    override void execute(ref Module mod, string sub_mod_name) {       
        assert(mod !is null);

        if (sub_mod_name !in mod.as_trees) {
        	err_logger.Error("couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
			return;
        }

        auto ast = mod.as_trees[sub_mod_name];
        if (ast is null) {
            err_logger.Error("null AST ? " ~ mod.name ~ " :: " ~ sub_mod_name);
            return;
        }

        foreach (node; ast) {
            if (node !is null) {
                super.process_node(node);
            }
        }
    }

    override string toString() const {
        return "decl-pass";
    }
}