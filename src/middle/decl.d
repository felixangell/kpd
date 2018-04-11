module sema.decl;

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

/// this pass will go through all declarations in the module
/// and declare/register them. in addition to this it will
/// build a virtualized scope, each declaration is local to its
/// scope
class Declaration_Pass : Top_Level_Node_Visitor, Semantic_Pass {
	Symbol_Table analyze_structure_type_node(ast.Structure_Type_Node s) {
		auto table = new Symbol_Table;
		foreach (idx, field; s.fields) {
			auto og_field = table.register_sym(new Symbol(field, field.name));
			if (og_field) {
				Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, field.get_tok_info(), og_field.get_tok_info());
			}
		}
		return table;
	}

	Symbol_Table analyze_anon_union_type_node(ast.Union_Type_Node u) {
		auto table = new Symbol_Table;
		foreach (idx, field; u.fields) {
			auto og_field = table.register_sym(new Symbol(field, field.name));
			if (og_field) {
				Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, field.get_tok_info(), og_field.get_tok_info());
			}
		}
		return table;
	}

	Symbol_Table analyze_trait_type_node(ast.Trait_Type_Node t) {
		auto table = new Symbol_Table;
		foreach (idx, attrib; t.attributes) {
			auto og_field = table.register_sym(new Symbol(attrib, attrib.twine));
			if (og_field) {
				Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, new Absolute_Token(attrib.twine), og_field.get_tok_info());
			}
		}
		return table;
	}

	void visit_structure_destructure(ast.Structure_Destructuring_Statement_Node stat) {
		foreach (name; stat.values) {
			auto existing = curr_sym_table.register_sym(new Symbol(stat, name));
			if (existing !is null) {
				Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, new Absolute_Token(name), existing.get_tok_info());
			}	
		}
	}

	override void visit_stat(ast.Statement_Node stat) {
		if (auto var = cast(Variable_Statement_Node) stat) {
			analyze_let_node(var);
		}
		else if (auto while_loop = cast(ast.While_Statement_Node) stat) {
			visit_block(while_loop.block);
		}
		else if (auto if_stat = cast(ast.If_Statement_Node) stat) {
			visit_block(if_stat.block);
		}
		else if (auto structure_destructure = cast(ast.Structure_Destructuring_Statement_Node) stat) {
			visit_structure_destructure(structure_destructure);
		}
		else {
			this.log(Log_Level.Warning, "decl: Unhandled statement " ~ to!string(stat));
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
		}
		else if (auto anon_union = cast(Union_Type_Node) tn) {
			auto table = analyze_anon_union_type_node(anon_union);
			table.name = name;
			table.reference = node;
			curr_sym_table.register_sym(name, table);
		}
		else if (auto trait = cast(Trait_Type_Node) tn) {
			auto table = analyze_trait_type_node(trait);
			table.name = name;
			table.reference = node;
			curr_sym_table.register_sym(name, table);
		}
		// TODO: traits.
		else {
			// just a symbol we dont care about the type

			auto existing = curr_sym_table.register_sym(new Symbol(node, node.twine));
			if (existing !is null) {
				Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, node.get_tok_info(), existing.get_tok_info());
			}
		}
	}

	string mangle_word(string word) {
		return to!string(word.length) ~ "" ~ word;
	}

	// TODO: a documented/well defined mangling scheme
	// that is capable of mangling the entire AST
	// for now, however, this is all we need.
	string mangle_type(ast.Type_Node t) {
		if (auto type_path = cast(ast.Type_Path_Node) t) {
			if (type_path.values.length == 1) {
				return mangle_word(type_path.values[0].lexeme);
			}
			// handle proper type paths...
		}
		else if (auto ptr = cast(ast.Pointer_Type_Node) t) {
			return mangle_word("ptr") ~ "_" ~ mangle_type(ptr.base_type);
		}
		else if (auto prim = cast(ast.Primitive_Type_Node) t) {
			// FIXME
			return mangle_word(prim.type_name.lexeme);
		}

		this.log(Log_Level.Error, "mangle_type: unhandled type node ", to!string(t), " ... ", to!string(typeid(t)),
			"\n", logger.blame_token(t.get_tok_info()));
		assert(0);
	}

	override void analyze_function_node(ast.Function_Node node) {
		// TODO:
		// we have two options here:
		// - change the sym_table structure so that
		//   we can store methods
		// - mangle the method and store it in the same sym table
		//
		// I feel like we should choose the first option because
		// we dont have enough type information to mangle anything
		// just yet, though mangling is a bit easier possibly to
		// store, but if we can't suffice without the type info, etc.
		// then it might be a bit more complicated and the first
		// option is definitely the way to go.

		// FIXME!!
		string symbol_name = node.name.lexeme;
		if (node.func_recv !is null) {
			// we have a function recv, this is a method.
			// instead of storing the symbol, we are going to mangle
			// the function receiver type and then mangle the function
			// name and store the symbol with the mangled name instead.
			// e.g. func (i int) do_stuff() will be stored and mangled as 
			// __3int_do_stuff
			symbol_name = "__" ~ mangle_type(node.func_recv.type) ~ "_" ~ mangle_word(
					symbol_name);
		}

		auto existing = curr_sym_table.register_sym(new Symbol(node, node.name));
		if (existing) {
			Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, node.get_tok_info(), existing.get_tok_info());
		}

		// some functions have no body!
		// these are prototype functions
		if (node.func_body is null) {
			return;
		}

		visit_block(node.func_body, delegate(Symbol_Table curr_stab) {
			// introduce recv (if applicable) into func body symbol table
			if (node.func_recv !is null) {
				curr_stab.register_sym(new Symbol(node.func_recv, node.func_recv.twine.lexeme));
			}

			// introduce parameters into function body symbol table
			foreach (param; node.params) {
				auto conflicting_param = curr_stab.register_sym(new Symbol(param, param.twine));
				if (conflicting_param) {
					Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, param.get_tok_info(), conflicting_param.get_tok_info());
					continue;
				}
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
			Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, node.get_tok_info(), existing.get_tok_info());
		}
	}

	override void execute(ref Module mod, AST as_tree) {
		foreach (node; as_tree) {
			if (node !is null) {
				super.process_node(node);
			}
		}
	}

	override string toString() const {
		return "decl-pass";
	}
}
