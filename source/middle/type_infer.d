module sema.type_infer;

import std.conv;

import ast;
import sema.visitor;
import sema.analyzer : Semantic_Pass;
import sema.range;
import sema.type;
import sema.infer;
import krug_module;
import err_logger;

class Type_Infer_Pass : Top_Level_Node_Visitor, Semantic_Pass {
	Scope current;

    Type_Inferrer inferrer;

	override void analyze_named_type_node(ast.Named_Type_Node node) {}

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

    void visit_variable_stat(ast.Variable_Statement_Node var) {
        inferrer.analyze(var, current.env);
    }

    void visit_call(ast.Call_Node call) {
        // TODO:
    }

    void visit_stat(ast.Statement_Node stat) {
    	if (auto var = cast(Variable_Statement_Node) stat) {
    		visit_variable_stat(var);
    	}
        else if (auto call = cast(Call_Node)stat) {
            visit_call(call);
        }
    	else {
	    	err_logger.Warn("type_infer: unhandled statement " ~ to!string(stat));
    	}
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
        return "type-infer-pass";
    }

}