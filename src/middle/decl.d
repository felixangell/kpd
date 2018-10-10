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

	// NOTE
	// FIXME whether or not the structure fields are mutable?
	// will have to see how this behaves when we have a structure
	// or rather a variable that is of type SomeStruct and is mutable
	// for now just make the stabs and the symbols mutable.
	Symbol_Table analyze_structure_type_node(ast.Structure_Type_Node s) {
		auto table = new Symbol_Table;
		foreach (idx, field; s.fields) {
			auto og_field = table.register_sym(new Symbol(field, field.name, true));
			if (og_field !is null) {
				Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, field.get_tok_info(), og_field.get_tok_info());
			}
		}
		return table;
	}

	Symbol_Table analyze_tuple_type_node(ast.Tuple_Type_Node t) {
		auto table = new Symbol_Table;
		foreach (idx, type; t.types) {
			auto og_type = table.register_sym(new Symbol(type, to!string(idx), true));
			
			// if this happens something is seriously broken.
			if (og_type !is null) {
				Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, type.get_tok_info(), og_type.get_tok_info());
			}
		}
		return table;
	}

	Symbol_Table analyze_anon_union_type_node(ast.Union_Type_Node u) {
		auto table = new Symbol_Table;
		foreach (idx, field; u.fields) {
			auto og_field = table.register_sym(new Symbol(field, field.name, true));
			if (og_field !is null) {
				Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, field.get_tok_info(), og_field.get_tok_info());
			}
		}
		return table;
	}

	Symbol_Table analyze_trait_type_node(ast.Trait_Type_Node t) {
		auto table = new Symbol_Table;
		foreach (idx, attrib; t.attributes) {
			auto og_field = table.register_sym(new Symbol(attrib, attrib.twine, true));
			if (og_field !is null) {
				Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, new Absolute_Token(attrib.twine), og_field.get_tok_info());
			}
		}
		return table;
	}

	Symbol_Table analyze_tagged_union_type_node(ast.Tagged_Union_Type_Node t) {
    		auto table = new Symbol_Table;
    		foreach (idx, field; t.fields) {
    			auto og_field = table.register_sym(new Symbol(field, field.identifier, true));
    			if (og_field !is null) {
    				Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, new Absolute_Token(field.identifier), og_field.get_tok_info());
    			}
    		}
    		return table;
    	}

	void visit_structure_destructure(ast.Structure_Destructuring_Statement_Node stat) {
		foreach (name; stat.values) {
			auto existing = curr_sym_table.register_sym(new Symbol(stat, name, stat.mutable));
			if (existing !is null) {
				Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, new Absolute_Token(name), existing.get_tok_info());
			}	
		}
	}

	// TODO tuple destructuring?

	override void visit_stat(ast.Statement_Node stat) {
		if (auto var = cast(Variable_Statement_Node) stat) {
			analyze_var_stat_node(var);
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
		else if (auto tuple = cast(Tuple_Type_Node) tn) {
			auto table = analyze_tuple_type_node(tuple);
			table.name = name;
			table.reference = node;
			curr_sym_table.register_sym(name, table);
		}
		else if (auto tagged_union = cast (Tagged_Union_Type_Node) tn) {
			auto table = analyze_tagged_union_type_node(tagged_union);
			table.name = name;
			table.reference = node;
			curr_sym_table.register_sym(name, table);
		}
		// TODO: traits.
		else {
			// just a symbol we dont care about the type

			// FIXME mutable or not?

			auto existing = curr_sym_table.register_sym(new Symbol(node, node.twine, true));
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
		// this is a method, we have to handle these
		// in a later pass.
		if (node.func_recv !is null) {
			return;
		}

		// functions are mutable.
		// TODO function mutability...
		auto existing = curr_sym_table.register_sym(new Symbol(node, node.name, true));
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
				curr_stab.register_sym(new Symbol(node.func_recv, node.func_recv.twine.lexeme, node.func_recv.mutable));
			}

			// introduce parameters into function body symbol table
			foreach (param; node.params) {
				auto conflicting_param = curr_stab.register_sym(new Symbol(param, param.twine, param.mutable));
				if (conflicting_param) {
					Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, param.get_tok_info(), conflicting_param.get_tok_info());
					continue;
				}
			}
		});
	}

	override void analyze_var_stat_node(ast.Variable_Statement_Node node) {
		auto existing = curr_sym_table.register_sym(new Symbol(node, node.twine, node.mutable));
		if (existing !is null) {
			Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, node.get_tok_info(), existing.get_tok_info());
		}
	}

	override void execute(ref Module mod, string sub_mod_name, AST as_tree) {
		foreach (ref node; as_tree) {
			if (node !is null) {
				super.process_node(node);
			}
		}
	}

	override string toString() const {
		return "decl-pass";
	}
}
