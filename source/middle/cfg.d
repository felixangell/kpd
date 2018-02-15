module sema.cfg;

import std.stdio;
import std.conv;

import err_logger;
import colour;
import ast;
import sema.analyzer : Semantic_Pass;
import sema.range;
import sema.symbol;
import sema.visitor;
import krug_module;

/// this pass will go through all declarations in the module
/// and declare/register them. in addition to this it will
/// build a virtualized scope, each declaration is local to its
/// scope
class CFG_Pass : Top_Level_Node_Visitor, Semantic_Pass
{
    Scope current;

    override void analyze_named_type_node(ast.Named_Type_Node node)
    {

    }

    override void analyze_function_node(ast.Function_Node node)
    {
        // some functions have no body!
        // these are prototype functions
        if (node.func_body !is null)
        {
            visit_block(node.func_body);
        }

        pop_scope();
    }

    override void analyze_let_node(ast.Variable_Statement_Node node)
    {
    }

    override void execute(ref Module mod, string sub_mod_name)
    {
        assert(mod !is null);

        if (sub_mod_name !in mod.as_trees)
        {
            err_logger.Error(
                    "couldn't find the AST for " ~ sub_mod_name ~ " in module " ~ mod.name ~ " ...");
            return;
        }

        current = mod.scopes[sub_mod_name];

        {
            auto ast = mod.as_trees[sub_mod_name];
            foreach (node; ast)
            {
                if (node !is null)
                {
                    super.process_node(node);
                }
            }
        }

        pop_scope();
    }

    Scope pop_scope()
    {
        auto old = current;
        current = current.outer;
        return old;
    }

    void visit_block(ast.Block_Node block)
    {
        assert(block.range !is null);
        current = block.range;

        foreach (stat; block.statements)
        {
            if (auto var = cast(Variable_Statement_Node) stat)
            {
                analyze_let_node(var);
            }
        }
    }

    override string toString() const
    {
        return "cfg-pass";
    }
}
