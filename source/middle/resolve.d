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

	// for example
	// a.b.c
	// resolve_via(sym of a, b)
	// look for b in sym of a 
	Symbol resolve_via(Symbol left, Expression_Node curr) {
		if (left is null) {
			return resolve(curr);
		}

		err_logger.Fatal("need to look for " ~ to!string(curr) ~ " in " ~ to!string(left));
		// look IN left for the current expr.
		return null;
	}

	Symbol resolve_path(ast.Path_Expression_Node path) {
		Symbol last = null;
		foreach (p; path.values) {
			last = resolve_via(last, p);
		}
		return last;
	}

	Symbol resolve(ast.Expression_Node node) {
		if (cast(ast.Integer_Constant_Node)node) {
			return null;
		}
		else if (auto binary = cast(ast.Binary_Expression_Node) node) {
			// i presume right now this is mostly for assignment
			// left = right
			resolve(binary.left);

			// how should this work
			return resolve(binary.right);
		}
		else if (auto path = cast(ast.Path_Expression_Node) node) {
			return resolve_path(path);
		}
		else if (auto sym_node = cast(ast.Symbol_Node) node) {
			// look for the symbol in the current scope recursively
			// searching outwards till we find it.
			Symbol sym = current.lookup_sym(sym_node.value.lexeme);
			if (sym is null) {
	            err_logger.Error([
	                "Unresolved reference to symbol '" ~ colour.Bold(sym_node.value.lexeme) ~ "':",
	                Blame_Token(sym_node.value)
	            ]);
	            return null;
			}
			return sym;
		}

		err_logger.Fatal("resolve: unhandled expression " ~ to!string(node));			
		assert(0);
	}

	override void analyze_named_type_node(ast.Named_Type_Node node) {

	}

    override void analyze_let_node(ast.Variable_Statement_Node var) {
    	if (var.value !is null) {
    		resolve(var.value);
    	}
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
    	if (auto var = cast(ast.Variable_Statement_Node) stat) {
    		analyze_let_node(var);
		} else if (auto binary = cast(ast.Binary_Expression_Node) stat) {
			resolve(binary);
		} else if (auto ifstat = cast(ast.If_Statement_Node) stat) {
			resolve(ifstat.condition);
		} else {
	    	err_logger.Warn("resolve: unhandled statement " ~ to!string(stat));
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
        return "resolve-pass";
    }

}