module sema.type_def;

import std.conv;

import ast;
import sema.visitor;
import sema.analyzer : Semantic_Pass;
import sema.range;
import sema.type;
import sema.infer;
import krug_module;
import err_logger;

// Type_Define_Pass defines all of the types, these include
// functions and structures
//
// we need to find a way to handle methods 
// in the type environments
class Type_Define_Pass : Top_Level_Node_Visitor, Semantic_Pass {
	Scope current;
	Type_Inferrer inferrer;

	void define_structure(string name, Structure_Type_Node s) {
		Type[] field_types;

		foreach (entry; s.fields.byKeyValue()) {
			// what if we fail to infer the type here because 
			// it has not been defined? 
			Structure_Field field = entry.value;
			field_types ~= inferrer.analyze(field.type, current.env);
		}

		auto structure_op = new Type_Operator(name, field_types);
		current.env.register_type(name, structure_op);
	}

	void define_type_node(string name, Type_Node t) {
		if (auto structure = cast(Structure_Type_Node) t) {
			define_structure(name, structure);
		}
		else {
			err_logger.Fatal("Unhandled type node " ~ to!string(t));
			assert(0);
		}
	}

	override void analyze_named_type_node(ast.Named_Type_Node node) {
        define_type_node(node.twine.lexeme, node.type);

        foreach (entry; current.env.data.byKeyValue()) {
        	err_logger.Verbose(entry.key ~ " is " ~ to!string(entry.value));
        }
    }

    override void analyze_function_node(ast.Function_Node node) {
        // some functions have no body!
        // these are prototype functions
        if (node.func_body !is null) {
    		visit_block(node.func_body);
        }

        foreach (entry; current.env.data.byKeyValue()) {
        	err_logger.Verbose(entry.key ~ " is " ~ to!string(entry.value));
        }

        pop_scope();
    }

    void visit_variable_stat(ast.Variable_Statement_Node var) {

    }

    void visit_stat(ast.Statement_Node stat) {
    	if (auto var = cast(Variable_Statement_Node) stat) {
    		visit_variable_stat(var);
    	}
    	else {
	    	err_logger.Warn("type_def: unhandled statement " ~ to!string(stat));
    	}
    }

    void visit_block(ast.Block_Node block) {
    	assert(block.range !is null);
        current = block.range;
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
        return "type-def-pass";
    }

}