module sema.name_resolve;

import std.conv;
import std.stdio;

import logger;
import ast;
import sema.visitor;
import sema.analyzer;
import sema.symbol;
import diag.engine;
import sema.type;
import krug_module;
import tok;
import compiler_error;

immutable bool NAME_RESOLVE_DEBUG = false;

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

			static if (NAME_RESOLVE_DEBUG) {
				this.log(Log_Level.Verbose, "LOOKING FOR ", name, " in:");
				s.dump_values();
			}

			if (name in s.symbols) {
				auto val = s.symbols[name];
				static if (NAME_RESOLVE_DEBUG) {
					this.log(Log_Level.Verbose, "LOCATED SYMBOL ", name, " . ", to!string(val));
				}
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

	Symbol_Table resolve_type_path(ast.Type_Path_Node type_path) {
		Symbol_Table last = curr_sym_table;
		foreach (i, p; type_path.values) {
			string sym_name = p.lexeme;

			Symbol_Value found_sym;
			if (i == 0) {
				// this will search MODULES too
				// we only want this if we're at the
				// start of the path.
				found_sym = find_symbol(last, sym_name);
			}
			else {
				found_sym = find_symbol_in_stab(last, sym_name);
			}

			if (found_sym is null) {
				Diagnostic_Engine.throw_error(compiler_error.UNRESOLVED_SYMBOL, new Absolute_Token(p));
				return null;
			}

			if (auto stab = cast(Symbol_Table) found_sym) {
				last = stab;
			}
			else if (i != type_path.values.length - 1) {
				Token next_tok = type_path.values[i + 1];
				// it's not a symbol table so there is no more
				// places for us to search and we still have
				// iterations left i.e. thinks to resolve.
				// throw an unresolved error
				Diagnostic_Engine.throw_error(compiler_error.UNRESOLVED_SYMBOL, new Absolute_Token(next_tok));
				return null;
			}
		}
		return last;
	}

	Symbol_Table resolve_type(ast.Type_Node t) {
		if (auto type_path = cast(Type_Path_Node) t) {
			return resolve_type_path(type_path);
		}
		else if (auto ptr = cast(Pointer_Type_Node) t) {
			return resolve_type(ptr.base_type);
		}
		else if (auto prim = cast(Primitive_Type_Node) t) {
			// all dandy. 
			// (the parser should have caught this)
			return null;
		}

		this.log(Log_Level.Error, "unhandled type node ", to!string(t), to!string(typeid(t)));
		return null;
	}

	Symbol_Table resolve_via(Symbol_Value s) {
		if (s.reference is null) {
			this.log(Log_Level.Error, "Symbol '", to!string(s), "' has no reference to an AST node, can't resolve it to a symbol table!");
			return null;
		}

		if (auto var = cast(ast.Variable_Statement_Node) s.reference) {
			return resolve_type(var.type);
		}
		else if (auto field = cast(ast.Structure_Field) s.reference) {
			return resolve_type(field.type);
		}
		else if (auto param = cast(ast.Function_Parameter) s.reference) {
			return resolve_type(param.type);
		}

		logger.verbose(to!string(s.reference), " has not been handled in resolve_via!");
		return null;
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
			}
			else {
				found_sym = find_symbol_in_stab(last, sym.value.lexeme);
			}

			e.resolved_symbol = found_sym;

			if (found_sym is null) {
				Diagnostic_Engine.throw_error(compiler_error.UNRESOLVED_SYMBOL, sym.get_tok_info());
				return;
			}

			if (auto stab = cast(Symbol_Table) found_sym) {
				last = stab;
			}
			else if (i != path.values.length - 1) {
				// let's try resolve it TO a symbol table, for example.
				// let felix Person
				// let blah = felix.age;
				// felix wont be a STAB, but Person is
				last = resolve_via(found_sym);
				if (last !is null) {
					// we found a symbol table
					// let's continue resolving
					continue;
				}

				Token next_tok = null;
				if (auto next_sym = cast(Symbol_Node) path.values[i + 1]) {
					next_tok = next_sym.value;
				}
				else {
					next_tok = sym.value;
				}

				// it's not a symbol table so there is no more
				// places for us to search and we still have
				// iterations left i.e. thinks to resolve.
				// throw an unresolved error
				Diagnostic_Engine.throw_error(compiler_error.UNRESOLVED_SYMBOL, new Absolute_Token(next_tok));
				return;
			}
		}

		// if we made it all the way here, our node has been resolved
		// nicely. we're going to give the node a link to the symbol table
		// it was resolved to
		path.resolved_to = last;
	}

	void analyze_unary_unary(ast.Unary_Expression_Node unary) {
		analyze_expr(unary.value);
	}

	void analyze_expr(ast.Expression_Node expr) {
		if (auto binary = cast(ast.Binary_Expression_Node) expr) {
			analyze_binary_expr(binary);
		}
		else if (auto paren = cast(ast.Paren_Expression_Node) expr) {
			analyze_expr(paren.value);
		}
		else if (auto path = cast(ast.Path_Expression_Node) expr) {
			analyze_path_expr(path);
		}
		else if (auto call = cast(ast.Call_Node) expr) {
			analyze_call(call);
		}
		else if (auto unary = cast(ast.Unary_Expression_Node) expr) {
			analyze_unary_unary(unary);
		}
		else if (auto c = cast(ast.Cast_Expression_Node) expr) {
			resolve_type(c.type);
		}
		else if (cast(ast.Integer_Constant_Node) expr) {
			// NOOP
		}
		else if (cast(ast.Float_Constant_Node) expr) {
			// NOOP
		}
		else if (cast(ast.String_Constant_Node) expr) {
			// NOOP
		}
		else {
			this.log(Log_Level.Error, "name_resolve: unhandled node " ~ to!string(expr) ~ "..." ~ to!string(typeid(expr)));
		}
	}

	void analyze_binary_expr(ast.Binary_Expression_Node binary) {
		if (binary.operand.lexeme == "as") {
			analyze_expr(binary.left);
			// TODO make sure that the right hand
			// side is a valid type.
			return;
		}

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

	void analyze_else_stat(ast.Else_Statement_Node else_stat) {
		visit_block(else_stat.block);	
	}

	void analyze_else_if_stat(ast.Else_If_Statement_Node else_if_stat) {
		analyze_expr(else_if_stat.condition);
		visit_block(else_if_stat.block);	
	}

	void analyze_call(ast.Call_Node call) {
		analyze_expr(call.left);
		
		foreach (a; call.args) {
			analyze_expr(a);
		}
	}

	override void visit_stat(ast.Statement_Node stat) {
		if (auto variable = cast(ast.Variable_Statement_Node) stat) {
			analyze_let_node(variable);
		}
		else if (auto expr = cast(ast.Expression_Node) stat) {
			analyze_expr(expr);
		}
		else if (auto while_loop = cast(ast.While_Statement_Node) stat) {
			analyze_while_stat(while_loop);
		}
		else if (auto if_stat = cast(ast.If_Statement_Node) stat) {
			analyze_if_stat(if_stat);
		}
		else if (auto else_stat = cast(ast.Else_Statement_Node) stat) {
			analyze_else_stat(else_stat);
		}
		else if (auto else_if_stat = cast(ast.Else_If_Statement_Node) stat) {
			analyze_else_if_stat(else_if_stat);
		}
		else if (auto call = cast(ast.Call_Node) stat) {
			analyze_call(call);
		}
		else if (auto ret = cast(ast.Return_Statement_Node) stat) {
			if (ret.value !is null) {
				analyze_expr(ret.value);
			}
		}
		else if (auto next = cast(ast.Next_Statement_Node) stat) {
			// NOP
		}
		else if (auto brk = cast(ast.Break_Statement_Node) stat) {
			// NOP
		}
		else if (auto loop = cast(ast.Loop_Statement_Node) stat) {
			// NOP
		}
		else {
			this.log(Log_Level.Error, "unhandled statement " ~ to!string(stat));
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
		return "name-resolve-pass";
	}

}
