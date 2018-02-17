module sema.name_resolve;

import std.conv;
import std.stdio;

import err_logger;
import ast;
import sema.visitor;
import sema.analyzer : Semantic_Pass;
import sema.symbol;
import diag.engine;
import sema.type;
import krug_module;
import compiler_error;

class Name_Resolve_Pass : Top_Level_Node_Visitor, Semantic_Pass {
    Module mod;

    Symbol_Value find_symbol(Symbol_Table table, string name) {
        auto sym = find_symbol_in_stab(table, name);
        if (sym) {
            return sym;
        }

        // we looked everywhere, so let's try a module!
        if (name in mod.edges) {
            auto other_mod = mod.edges[name];

            // TODO search in specific submodule if we can

            // For now there is no submodule to specifically
            // look at so we have to copy ALL the symbols from
            // each submodule into one large table which we
            // can search in
            Symbol_Table merge = new Symbol_Table();
            foreach (table; other_mod.sym_tables) {
                foreach (entry; table.symbols.byKeyValue()) {
                    merge.symbols[entry.key] = entry.value;
                }
            }
            return cast(Symbol_Value) merge;
        }

        return null;
    }

    Symbol_Value find_symbol_in_stab(Symbol_Table t, string name) {
        for (Symbol_Table s = t; s !is null; s = s.outer) {
            err_logger.Verbose("LOOKING FOR ", name, " in:");
            s.dump_values();

            if (name in s.symbols) {
                auto val = s.symbols[name];
                err_logger.Verbose("LOCATED SYMBOL ", name, " . ", to!string(val));
                return val;
            }
        }
        return null;
    }

    override void analyze_named_type_node(ast.Named_Type_Node node) {

    }

    override void analyze_let_node(ast.Variable_Statement_Node var) {
        if (var.value !is null) {
            analyze_expr(var.value);
        }
    }

    override void analyze_function_node(ast.Function_Node node) {
        // some functions have no body!
        // these are prototype functions
        if (node.func_body !is null) {
            visit_block(node.func_body);
        }
    }

    void analyze_path_expr(ast.Path_Expression_Node path) {
        Symbol_Table last = curr_sym_table;
        foreach (i, e; path.values) {
            auto sym = cast(ast.Symbol_Node) e;
            if (!sym) {
                // what do we do here?
                continue;
            }

            Symbol_Value found_sym;
            if (i == 0) {
                // this will search MODULES too
                // we only want this if we're at the
                // start of the path.
                found_sym = find_symbol(last, sym.value.lexeme);
            } else {
                found_sym = find_symbol_in_stab(last, sym.value.lexeme);
            }

            if (found_sym is null) {
                Diagnostic_Engine.throw_error(compiler_error.UNRESOLVED_SYMBOL, sym.value);
                return;
            }

            if (auto stab = cast(Symbol_Table) found_sym) {
                last = stab;
            } else if (i != path.values.length - 1) {
                Token next_tok = null;
                if (auto next_sym = cast(Symbol_Node) path.values[i + 1]) {
                    next_tok = next_sym.value;
                } else {
                    next_tok = sym.value;
                }

                // it's not a symbol table so there is no more
                // places for us to search and we still have
                // iterations left i.e. thinks to resolve.
                // throw an unresolved error
                Diagnostic_Engine.throw_error(compiler_error.UNRESOLVED_SYMBOL, next_tok);
                return;
            }
        }
    }

    void analyze_unary_unary(ast.Unary_Expression_Node unary) {
        analyze_expr(unary.value);
    }

    void analyze_expr(ast.Expression_Node expr) {
        if (auto binary = cast(ast.Binary_Expression_Node) expr) {
            analyze_binary_expr(binary);
        } else if (auto path = cast(ast.Path_Expression_Node) expr) {
            analyze_path_expr(path);
        } else if (auto call = cast(ast.Call_Node) expr) {
            analyze_call(call);
        } else if (auto unary = cast(ast.Unary_Expression_Node) expr) {
            analyze_unary_unary(unary);
        } else if (cast(ast.Integer_Constant_Node) expr) {
            // NOOP
        } else if (cast(ast.Float_Constant_Node) expr) {
            // NOOP
        } else if (cast(ast.String_Constant_Node) expr) {
            // NOOP
        } else {
            err_logger.Warn("name_resolve: unhandled node " ~ to!string(expr));
        }
    }

    void analyze_binary_expr(ast.Binary_Expression_Node binary) {
        analyze_expr(binary.left);
        analyze_expr(binary.right);
    }

    void analyze_while_stat(ast.While_Statement_Node while_loop) {
        analyze_expr(while_loop.condition);
        visit_block(while_loop.block);
    }

    void analyze_if_stat(ast.If_Statement_Node if_stat) {
        analyze_expr(if_stat.condition);
        visit_block(if_stat.block);
    }

    void analyze_call(ast.Call_Node call) {
        analyze_expr(call.left);
    }

    override void visit_stat(ast.Statement_Node stat) {
        if (auto variable = cast(ast.Variable_Statement_Node) stat) {
            analyze_let_node(variable);
        } else if (auto expr = cast(ast.Expression_Node) stat) {
            analyze_expr(expr);
        } else if (auto while_loop = cast(ast.While_Statement_Node) stat) {
            analyze_while_stat(while_loop);
        } else if (auto if_stat = cast(ast.If_Statement_Node) stat) {
            analyze_if_stat(if_stat);
        } else if (auto call = cast(ast.Call_Node) stat) {
            analyze_call(call);
        } else {
            err_logger.Warn("name_resolve: unhandled statement " ~ to!string(stat));
        }
    }

    override void execute(ref Module mod, string sub_mod_name) {
        assert(mod !is null);
        this.mod = mod;

        if (sub_mod_name !in mod.as_trees) {
            err_logger.Error(
                    "couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
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
