module sema.top_level_type_decl;

import std.conv;
import std.stdio;

import logger;
import ast;
import sema.visitor;
import sema.analyzer : Semantic_Pass, log;
import sema.symbol;
import diag.engine;
import sema.infer;
import sema.type;
import krug_module;
import compiler_error;

// introduce all of the top level types into
// the type system
class Top_Level_Type_Decl_Pass : Top_Level_Node_Visitor, Semantic_Pass {
	Type_Inferrer inferrer;

	void declare_structure(string name, ast.Structure_Type_Node s) {
		string[] names;
		Type[] types;

		names.reserve(s.fields.length);
		types.reserve(s.fields.length);

		foreach (field; s.fields) {
			types ~= inferrer.analyze(field.type, curr_sym_table.env);
			names ~= field.name.lexeme;
		}

		auto s_type = new Structure(types, names);
		curr_sym_table.env.register_type(name, s_type);
	}

	void declare_alias(string name, ast.Type_Node t) {
		auto type = inferrer.analyze(t, curr_sym_table.env);
		curr_sym_table.env.register_type(name, type);
	}

	override void analyze_named_type_node(ast.Named_Type_Node node) {
		const auto name = node.twine.lexeme;

		if (auto structure = cast(Structure_Type_Node) node.type) {
			declare_structure(name, structure);
		}
		// TODO traits
		// TODO enums
		// TODO unions
		else {
			declare_alias(name, node.type);
		}
	}

	override void analyze_var_stat_node(ast.Variable_Statement_Node var) {
		
	}

	override void analyze_function_node(ast.Function_Node func) {
		auto func_type = inferrer.analyze(func, curr_sym_table.env);
		curr_sym_table.env.register_type(func.name.lexeme, func_type);
	}

	override void visit_stat(ast.Statement_Node stat) {
		this.log(Log_Level.Error, "unhandled statement " ~ to!string(stat));
	}

	override void execute(ref Module mod, AST as_tree) {
		foreach (node; as_tree) {
			if (node !is null) {
				super.process_node(node);
			}
		}
	}

	override string toString() const {
		return "top-level-type-decl-pass";
	}

}
