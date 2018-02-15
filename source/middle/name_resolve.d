module sema.name_resolve;

import std.conv;

import ast;
import sema.visitor;
import sema.analyzer : Semantic_Pass;
import sema.range;
import sema.symbol;
import sema.type;
import krug_module;
import err_logger;

class Name_Resolve_Pass : Top_Level_Node_Visitor, Semantic_Pass {
	Scope current;
    Symbol_Table curr_sym_table;

	override void analyze_named_type_node(ast.Named_Type_Node node) {

	}

    override void analyze_let_node(ast.Variable_Statement_Node var) {
        
    }

    override void analyze_function_node(ast.Function_Node node) {
        // some functions have no body!
        // these are prototype functions
        if (node.func_body !is null) {
    		visit_block(node.func_body);
        }
    }

    void visit_stat(ast.Statement_Node stat) {
        if (auto variable = cast(ast.Variable_Statement_Node) stat) {
            analyze_let_node(variable);
        } else {
            err_logger.Warn("resolve: unhandled statement " ~ to!string(stat));            
        }
    }

    void visit_block(ast.Block_Node block) {
    	assert(block.sym_table !is null);
        curr_sym_table = block.sym_table;

        foreach (stat; block.statements) {
            if (stat is null) {
                err_logger.Fatal("what? " ~ to!string(block));
            }
            visit_stat(stat);
        }

        curr_sym_table = curr_sym_table.parent;
    }

	override void execute(ref Module mod, string sub_mod_name) {       
        assert(mod !is null);

        if (sub_mod_name !in mod.as_trees) {
        	err_logger.Error("couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
			return;
        }

        // current = mod.scopes[sub_mod_name];
        curr_sym_table = mod.sym_tables[sub_mod_name];

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