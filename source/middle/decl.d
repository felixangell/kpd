module sema.decl;

import std.stdio;
import std.conv;

import err_logger;
import colour;
import ast;
import sema.analyzer : Semantic_Pass;
import sema.infer : Type_Environment;
import sema.symbol;
import sema.visitor;
import krug_module;

/// this pass will go through all declarations in the module
/// and declare/register them. in addition to this it will
/// build a virtualized scope, each declaration is local to its
/// scope
class Declaration_Pass : Top_Level_Node_Visitor, Semantic_Pass {
    Symbol_Table analyze_structure_type_node(ast.Structure_Type_Node s) {
        auto table = new Symbol_Table;
        foreach (idx, field; s.fields) {
            table.register_sym(new Symbol(field, field.name));
            // NOTE: we do not have to check for conflicts here
            // because these are checked for when parsing. we could
            // be true to the linear-ness of the compiler and store
            // the conflicts as a collision in the hashmap or something
            // but instead I've decided to check earlier.
            // same applies for union types, and any other type
            // with a field member type thing.
        }
        return table;
    }

    Symbol_Table analyze_anon_union_type_node(ast.Union_Type_Node u) {
        auto table = new Symbol_Table;
        foreach (idx, field; u.fields) {
            table.register_sym(new Symbol(field, field.name));
        }
        return table;
    }

    override void visit_stat(ast.Statement_Node stat) {
        if (auto var = cast(Variable_Statement_Node) stat) {
            analyze_let_node(var);
        } else if (auto while_loop = cast(ast.While_Statement_Node) stat) {
            visit_block(while_loop.block);
        } else if (auto if_stat = cast(ast.If_Statement_Node) stat) {
            visit_block(if_stat.block);
        } else {
            err_logger.Warn("decl: Unhandled statement " ~ to!string(stat));
        }
    }

    override void analyze_named_type_node(ast.Named_Type_Node node) {
        const auto name = node.twine.lexeme;

        // analyze the type node
        auto tn = node.type;
        if (auto structure = cast(Structure_Type_Node) tn) {
            auto table = analyze_structure_type_node(structure);
            table.name = name;
            table.reference = node;
            curr_sym_table.register_sym(name, table);
        } else if (auto anon_union = cast(Union_Type_Node) tn) {
            auto table = analyze_anon_union_type_node(anon_union);
            table.name = name;
            table.reference = node;
            curr_sym_table.register_sym(name, table);
        } 
        // TODO: traits.
        else {
            // just a symbol we dont care about the type

            auto existing = curr_sym_table.register_sym(new Symbol(node, node.twine));
            if (existing !is null) {
                err_logger.Error("Named type '" ~ colour.Bold(
                    node.twine.lexeme) ~ "' defined here:", Blame_Token(node.twine),
                    "Conflicts with symbol defined here:", Blame_Token(existing.tok));
            }
        }
    }

    override void analyze_function_node(ast.Function_Node node) {
        auto existing = curr_sym_table.register_sym(new Symbol(node, node.name));
        if (existing !is null) {
            err_logger.Error("Function '" ~ colour.Bold(node.name.lexeme) ~ "' defined here:",
                Blame_Token(node.name), "Conflicts with symbol defined here:",
                Blame_Token(existing.tok));
        }

        writeln("before entering ", node.name.lexeme, " block: ", &curr_sym_table);

        // some functions have no body!
        // these are prototype functions
        if (node.func_body is null) {
            return;
        }

        visit_block(node.func_body, delegate () {
            foreach (param_entry; node.params.byKeyValue()) {
                auto param = param_entry.value;
                // we don't have to check for conflicts here because
                // this HAS to be done during the parsing stage!
                curr_sym_table.register_sym(new Symbol(param, param.twine.lexeme));
            }
        });

        // TODO check that the function receiver
        // is a valid symbol

        // TODO store a ptr to this method
        // in the Structure it's a member of.
        // if func recvr exists.
    }

    override void analyze_let_node(ast.Variable_Statement_Node node) {
        auto existing = curr_sym_table.register_sym(new Symbol(node, node.twine));
        if (existing !is null) {
            err_logger.Error("Variable '", colour.Bold(node.twine.lexeme), "' defined here:\n", 
                Blame_Token(node.twine), 
                "Conflicts with symbol defined here: \n");
        }
    }

    override void execute(ref Module mod, string sub_mod_name) {
        assert(mod !is null);

        if (sub_mod_name !in mod.as_trees) {
            err_logger.Error("couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
            return;
        }

        mod.sym_tables[sub_mod_name] = push_sym_table();

        {
            auto ast = mod.as_trees[sub_mod_name];
            foreach (node; ast) {
                if (node !is null) {
                    super.process_node(node);
                }
            }
        }
    }

    override string toString() const {
        return "decl-pass";
    }
}
