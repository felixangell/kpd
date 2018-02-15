module sema.visitor;

import ast;
import err_logger;

import std.conv;

// a bunch of visitor helper things

class AST_Visitor
{
    abstract void process_node(ast.Node node);
}

class Top_Level_Node_Visitor : AST_Visitor
{
    abstract void analyze_named_type_node(ast.Named_Type_Node);
    abstract void analyze_function_node(ast.Function_Node);
    abstract void analyze_let_node(ast.Variable_Statement_Node);

    override void process_node(ast.Node node)
    {
        if (auto named_type_node = cast(ast.Named_Type_Node) node)
        {
            analyze_named_type_node(named_type_node);
        }
        else if (auto func_node = cast(ast.Function_Node) node)
        {
            analyze_function_node(func_node);
        }
        else if (auto var_node = cast(ast.Variable_Statement_Node) node)
        {
            analyze_let_node(var_node);
        }
        else
        {
            err_logger.Fatal("unhandled node in " ~ to!string(
                    this) ~ " execution:\n" ~ to!string(node));
        }
    }
}
