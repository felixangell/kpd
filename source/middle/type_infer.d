module sema.type_infer;

import ast;
import sema.visitor;
import sema.analyzer : Semantic_Pass;
import sema.range;
import sema.type;
import krug_module;
import err_logger;

struct Type_Inferrer {

}

// type environment contains all of the types that have
// been registered, this works _alongside_ the scope though
// it could be embedded into the scope.
//
// basically we have the top most type environment which
// contains all of our primitives
// whenever we enter a new scope and we create new types
// we register them, then we look up types in the type environment
// working our way outwards, 
//
// though perhaps an optimisation could
// be to copy all of the primitive types into any
// new child scopes otherwise we will have to search N
// layers outwards to get something as simple as a boolean
// and N could be a big number!
class Type_Environment {
	Type_Environment parent;

	this() {
		
	}

	Type[string] environment;

	// for example we could register that
	// true -> bool
	// false -> bool
	// or add -> f(int, int) : int
	void register_type(string key, Type t) {
		assert(key !in environment);
		environment[key] = t;
	}
}

class Type_Inferrer_Pass : Top_Level_Node_Visitor, Semantic_Pass {
	Scope current;

	override void analyze_named_type_node(ast.Named_Type_Node node) {
        
    }

    override void analyze_function_node(ast.Function_Node node) {
        // some functions have no body!
        // these are prototype functions
        if (node.func_body !is null) {
    		visit_block(node.func_body);
        }

        pop_scope();
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
        return "type-infer-pass";
    }

}