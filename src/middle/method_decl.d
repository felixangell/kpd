module sema.method_decl;

import std.stdio;
import std.conv;

import logger;
import colour;
import ast;
import diag.engine;
import compiler_error;
import tok;

import sema.analyzer;
import sema.infer : Type_Environment;
import sema.symbol;
import sema.type;
import sema.visitor;
import krug_module;

/// 
class Method_Declaration_Pass : Top_Level_Node_Visitor, Semantic_Pass {

	override void visit_stat(ast.Statement_Node stat) {
		this.log(Log_Level.Warning, "Unhandled statement " ~ to!string(stat));
	}

	override void analyze_named_type_node(ast.Named_Type_Node node) {
	}

	Symbol_Value get_type_sym(ast.Type_Node t) {
		if (auto ptr = cast(ast.Pointer_Type_Node) t) {
			return get_type_sym(ptr.base_type);
		}
		else if (auto path = cast(ast.Type_Path_Node) t) {
			assert(path.values.length == 1);
			const auto sym_name = path.values[0].lexeme;
			if (sym_name in curr_sym_table.symbols) {
				return curr_sym_table.symbols[sym_name];
			}
			assert(0);
		}

		this.log(Log_Level.Warning, "Unhandled type node " ~ to!string(t) ~ ", " ~ to!string(typeid(t)));
		assert(0);
	}

	override void analyze_function_node(ast.Function_Node node) {
		// this is not a method so we dont care
		// leave this function!
		if (node.func_recv is null) {
			return;
		}
		auto recv = node.func_recv;
		
		auto sym = get_type_sym(recv.type);
		if (auto stab = cast(Symbol_Table) sym) {
			auto existing = stab.register_sym(node.name.lexeme, new Symbol(node, node.name, true));		
			if (existing) {
				Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, new Absolute_Token(node.name), new Absolute_Token(existing.tok));
			}
			return;
		}
		assert(0);
	}

	override void analyze_var_stat_node(ast.Variable_Statement_Node node) {

	}

	override void execute(ref Module mod, AST as_tree) {
		foreach (node; as_tree) {
			if (node !is null) {
				super.process_node(node);
			}
		}
	}

	override string toString() const {
		return "method-decl-pass";
	}
}
