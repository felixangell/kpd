module sema.visitor;

import ast;
import err_logger;
import sema.symbol;
import sema.infer : Type_Environment;

import std.conv;


class AST_Visitor {
    abstract void process_node(ast.Node node);
}

class Top_Level_Node_Visitor : AST_Visitor {
    protected Symbol_Table curr_sym_table;

    abstract void analyze_named_type_node(ast.Named_Type_Node);
    abstract void analyze_function_node(ast.Function_Node);
    abstract void analyze_let_node(ast.Variable_Statement_Node);

    abstract void visit_stat(ast.Statement_Node);

    Symbol_Table push_sym_table() {
        if (curr_sym_table is null) {
            curr_sym_table = new Symbol_Table;
            return curr_sym_table;
        }

        if (curr_sym_table.child !is null) {
            curr_sym_table = curr_sym_table.child;
            return curr_sym_table;
        }

        auto new_table = new Symbol_Table;
        new_table.id = curr_sym_table.id + 1;
        new_table.env = new Type_Environment(curr_sym_table.env);

        // do the swap.
        curr_sym_table.child = new_table;
        new_table.parent = curr_sym_table;
        curr_sym_table = new_table;

        return new_table;
    }

    void leave_sym_table() {
        if (curr_sym_table.parent !is null) {
            curr_sym_table = curr_sym_table.parent;
        }
    }

    void visit_block(ast.Block_Node block, void delegate() stuff = null) {
        // this should ONLY happen on the first pass...
        // maybe have a check to throw an error if 
        // this occurs after the decl pass.
        if (block.sym_table is null) {
            err_logger.Verbose("Setting up a symbol table in block");
            block.sym_table = push_sym_table();
        }

        curr_sym_table = block.sym_table;

        foreach (stat; block.statements) {
            if (stat is null) {
                err_logger.Warn("null statement in block? " ~ to!string(block));
                continue;
            }

            // handle nested blocks
            if (auto b = cast(Block_Node) stat) {
                visit_block(b);
            } else {
                visit_stat(stat);                
            }
        }

        if (stuff !is null) {
            stuff();
        }

        leave_sym_table();
    }

    override void process_node(ast.Node node) {
        if (auto named_type_node = cast(ast.Named_Type_Node) node) {
            analyze_named_type_node(named_type_node);
        } else if (auto func_node = cast(ast.Function_Node) node) {
            analyze_function_node(func_node);
        } else if (auto var_node = cast(ast.Variable_Statement_Node) node) {
            analyze_let_node(var_node);
        } else {
            err_logger.Fatal("unhandled node in " ~ to!string(
                    this) ~ " execution:\n" ~ to!string(node));
        }
    }
}
