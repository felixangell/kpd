module sema.type_def;

import std.stdio;
import std.conv;

import ast;
import sema.visitor;
import sema.analyzer : Semantic_Pass;
import sema.symbol;
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
    Symbol_Table curr_sym_table;
    Type_Inferrer inferrer;

    void define_structure(string name, Structure_Type_Node s) {
        err_logger.Verbose("defining structure ", name);

        foreach (entry; curr_sym_table.symbols.byKeyValue()) {
            err_logger.Verbose(entry.key, " is ", to!string(entry.value));
        }

        assert(name in curr_sym_table.symbols);

        auto structure_sym_tab = cast(Symbol_Table) curr_sym_table.symbols[name];
        if (!structure_sym_tab) {
            writeln("not going to infer structure type node apparently");
            return;
        }
        curr_sym_table = structure_sym_tab;

        Type[] field_types;

        foreach (entry; s.fields.byKeyValue()) {
            // what if we fail to infer the type here because 
            // it has not been defined? 
            Structure_Field field = entry.value;
            field_types ~= inferrer.analyze(field.type, curr_sym_table.env);
        }

        auto structure_op = new Type_Operator(name, field_types);
        curr_sym_table.env.register_type(name, structure_op);

        leave_sym_table();
    }

    void define_type_node(string name, Type_Node t) {
        if (auto structure = cast(Structure_Type_Node) t) {
            define_structure(name, structure);
        } else {
            err_logger.Fatal("Unhandled type node " ~ to!string(t));
            assert(0);
        }
    }

    override void analyze_named_type_node(ast.Named_Type_Node node) {
        define_type_node(node.twine.lexeme, node.type);

        foreach (entry; curr_sym_table.env.data.byKeyValue()) {
            err_logger.Verbose(entry.key ~ " is " ~ to!string(entry.value));
        }
    }

    override void analyze_let_node(ast.Variable_Statement_Node var) {
        auto var_type = inferrer.analyze(var, curr_sym_table.env);
        curr_sym_table.env.register_type(var.twine.lexeme, var_type);

        foreach (entry; curr_sym_table.env.data.byKeyValue()) {
            err_logger.Verbose(entry.key ~ " is " ~ to!string(entry.value));
        }
    }

    override void analyze_function_node(ast.Function_Node node) {
        err_logger.Verbose("Analyzing function node ", node.name.lexeme);

        Type[] types;
        foreach (p; node.params) {
            types ~= inferrer.analyze(p.type, curr_sym_table.env);
        }

        // assume void return type because 
        // return_type can be null.
        Type ret = prim_type("void");
        if (node.return_type !is null) {
            inferrer.analyze(node.return_type, curr_sym_table.env);
        }

        curr_sym_table.env.register_type(node.name.lexeme, new Function(ret, types));

        // some functions have no body!
        // these are prototype functions
        if (node.func_body is null) {
            return;
        }

        visit_block(node.func_body, delegate() {
            foreach (entry; curr_sym_table.env.data.byKeyValue()) {
                err_logger.Verbose(entry.key ~ " is " ~ to!string(entry.value));
            }
        });
    }

    override void visit_stat(ast.Statement_Node stat) {
        if (auto var = cast(Variable_Statement_Node) stat) {
            analyze_let_node(var);
        } else if (auto if_stat = cast(If_Statement_Node) stat) {
            visit_block(if_stat.block);
        } else if (auto while_loop = cast(While_Statement_Node) stat) {
            visit_block(while_loop.block);
        } else if (auto loop = cast(Loop_Statement_Node) stat) {
            visit_block(loop.block);
        } else if (cast(Call_Node) stat) {
            // NOOP
        } else {
            err_logger.Warn("type_def: unhandled statement " ~ to!string(stat));
        }
    }

    override void execute(ref Module mod, string sub_mod_name) {
        assert(mod !is null);

        if (sub_mod_name !in mod.as_trees) {
            err_logger.Error(
                    "couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
            return;
        }

        auto ast = mod.as_trees[sub_mod_name];
        curr_sym_table = mod.sym_tables[sub_mod_name];
        assert(curr_sym_table !is null);

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
