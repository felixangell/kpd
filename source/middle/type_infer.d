module sema.type_infer;

import std.conv;

import ast;
import sema.visitor;
import sema.analyzer : Semantic_Pass;
import sema.type;
import sema.infer;
import krug_module;
import err_logger;

class Type_Infer_Pass : Top_Level_Node_Visitor, Semantic_Pass {
    Type_Inferrer inferrer;

    override void analyze_named_type_node(ast.Named_Type_Node node) {
    }

    override void analyze_let_node(ast.Variable_Statement_Node var) {
        var.realType = inferrer.analyze(var, curr_sym_table.env);
    }

    override void analyze_function_node(ast.Function_Node node) {
        // some functions have no body!
        // these are prototype functions
        if (node.func_body !is null) {
            visit_block(node.func_body);
        }
    }

    void visit_while_loop(ast.While_Statement_Node while_loop) {
        // TODO. this should be a boolean
        // inferrer.analyze(while_loop.condition, curr_sym_table.env);
        pragma(msg, "while loop infer");
    }

    void visit_call(ast.Call_Node call) {
        // TODO:
    }

    override void visit_stat(ast.Statement_Node stat) {
        if (auto var = cast(Variable_Statement_Node) stat) {
            analyze_let_node(var);
        } else if (auto call = cast(Call_Node) stat) {
            visit_call(call);
        } else if (auto while_loop = cast(While_Statement_Node) stat) {
            visit_while_loop(while_loop);
        } else {
            err_logger.Warn("type_infer: unhandled statement " ~ to!string(stat));
        }
    }

    override void execute(ref Module mod, string sub_mod_name) {
        assert(mod !is null);

        if (sub_mod_name !in mod.as_trees) {
            err_logger.Error(
                    "couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
            return;
        }

        curr_sym_table = mod.sym_tables[sub_mod_name];
        assert(curr_sym_table !is null);

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
