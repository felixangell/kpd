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

	override void analyze_var_stat_node(ast.Variable_Statement_Node var) {
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

			Symbol_Value found_sym = find_symbol_in_stab(last, sym_name);
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
				// iterations left i.e. things to resolve.
				// throw an unresolved error
				Diagnostic_Engine.throw_error(compiler_error.UNRESOLVED_SYMBOL, new Absolute_Token(next_tok));
				assert(0);
			}
		}
		return last;
	}

	Symbol_Table resolve_tuple(ast.Tuple_Type_Node tuple) {
		assert(0);
	}

	Symbol_Table resolve_type(ast.Type_Node t) {
		if (auto type_path = cast(Type_Path_Node) t) {
			return resolve_type_path(type_path);
		}
		
		else if (auto ptr = cast(Pointer_Type_Node) t) {
			return resolve_type(ptr.base_type);
		}

		else if (auto tuple = cast(Tuple_Type_Node) t) {
			return resolve_tuple(tuple);
		}

		// TODO structure type node

		else if (auto prim = cast(Primitive_Type_Node) t) {
			// all dandy. 
			// (the parser should have caught this)
			return null;
		}

		if (t is null) {
			assert(0, "oh dear");
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

	Symbol_Node unwrap_sym(ast.Expression_Node e) {
		if (auto sym = cast(ast.Symbol_Node) e) {
			return sym;
		}
		else if (auto path = cast(ast.Path_Expression_Node) e) {
			return unwrap_sym(path.values[$-1]);
		}
		else if (auto call = cast(ast.Call_Node) e) {
			return unwrap_sym(call.left);
		}
		else if (auto integer = cast(ast.Integer_Constant_Node) e) {
			// NOTE this is a hack for tuples. we basically
			// wrap the number as a symbol node and since
			// a tuple type registers it's fields as the index
			// e.g. 0, 1, 2, 3
			// this should resolve properly!
			return new Symbol_Node(integer.tok);
		}
		else {
			logger.fatal(logger.blame_token(e.get_tok_info()), "unwrap_sym: unhandled expr ", to!string(typeid(e)));
			assert(0);
		}
	}

	// looks for the right hand in the module specified on
	// the left hand.
	void analyze_module_access(ast.Module_Access_Node man) {
		const auto name = man.left.value.lexeme;
		if (name !in mod.edges) {
			Diagnostic_Engine.throw_error(compiler_error.UNRESOLVED_SYMBOL, man.left.get_tok_info);
			return;
		}

		auto other_mod = mod.edges[name];
		
		// we have to manually resolve the left
		// we already know what is it though its
		// simply the modules symbol table.
		man.left.resolved_symbol = other_mod.sym_tables;

		look_expr_via(other_mod.sym_tables, man.right);
	}

	Symbol_Table look_expr_via(Symbol_Table table, Expression_Node[] values...) {
		Symbol_Table last = table;
		foreach (ref i, e; values) {
			// TODO wriet a note here
			// about how tuples work.
			auto sym = unwrap_sym(e);
			if (!sym) {
				// what do we do here?
				logger.fatal(logger.blame_token(e.get_tok_info()), "not a symbol_node?!", to!string(typeid(e)));
				continue;
			}

			Symbol_Value found_sym = find_symbol_in_stab(last, sym.value.lexeme);
			if (found_sym is null) {
				Diagnostic_Engine.throw_error(compiler_error.UNRESOLVED_SYMBOL, sym.get_tok_info());
				return null;
			}

			e.resolved_symbol = found_sym;

			if (auto stab = cast(Symbol_Table) found_sym) {
				last = stab;
			}
			else if (i != values.length - 1) {
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
				if (auto next_sym = cast(Symbol_Node) values[i + 1]) {
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
				return null;
			}
		}
		return last;
	}

	void analyze_path_expr(ast.Path_Expression_Node path) {
		// if we made it all the way here, our node has been resolved
		// nicely. we're going to give the node a link to the symbol table
		// it was resolved to
		path.resolved_to = look_expr_via(curr_sym_table, path.values);
	}

	void analyze_unary_unary(ast.Unary_Expression_Node unary) {
		analyze_expr(unary.value);
	}

	// TODO these are resolved via the rhand of the node
	// so for example
	// let { foo, bar, baz } = blah;
	// we look for foo bar and baz in the right hand
	// blah symbol tables.
	void resolve_structure_destructure(ast.Structure_Destructuring_Statement_Node stat) {
		// TODO
		analyze_expr(stat.rhand);
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
		else if (auto man = cast(ast.Module_Access_Node) expr) {
			analyze_module_access(man);
		}
		else if (auto call = cast(ast.Call_Node) expr) {
			analyze_call(call);
		}
		else if (auto unary = cast(ast.Unary_Expression_Node) expr) {
			analyze_unary_unary(unary);
		}
		else if (auto c = cast(ast.Cast_Expression_Node) expr) {
			resolve_type(c.type);
			analyze_expr(c.left);
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
		else if (cast(ast.Boolean_Constant_Node) expr) {
			// NOP
		}
		else if (cast(ast.Rune_Constant_Node) expr) {
			// NOP
		}
		else if (auto lambda = cast(ast.Lambda_Node) expr) {
			// TODO NOP
		}
		else if (auto index = cast(ast.Index_Expression_Node) expr) {
			analyze_expr(index.array);
			analyze_expr(index.index);
		}
		else {
			this.log(Log_Level.Error, "name_resolve: unhandled node " ~ to!string(expr) ~ "..." ~ to!string(typeid(expr)),
				"\n", logger.blame_token(expr.get_tok_info()));
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

	void analyze_for_stat(ast.For_Statement_Node for_loop) {
		analyze_expr(for_loop.condition);
		analyze_expr(for_loop.step);
		visit_block(for_loop.block);
	}

	void analyze_loop_stat(ast.Loop_Statement_Node loop) {
		visit_block(loop.block);
	}

	void analyze_if_stat(ast.If_Statement_Node if_stat) {
		analyze_expr(if_stat.condition);
		visit_block(if_stat.block);
		foreach (ref idx, elif; if_stat.else_ifs) {
			analyze_else_if_stat(elif);
		}
		if (if_stat.else_stat !is null) {
			analyze_else_stat(if_stat.else_stat);
		}
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

	void resolve_match(ast.Switch_Statement_Node match) {
		analyze_expr(match.condition);

		// TODO scope etc.
		foreach (a; match.arms) {
			foreach (v; a.expressions) {
				analyze_expr(v);
			}
			visit_block(a.block);
		}
	}

	override void visit_stat(ast.Statement_Node stat) {
		if (auto variable = cast(ast.Variable_Statement_Node) stat) {
			analyze_var_stat_node(variable);
		}
		else if (auto expr = cast(ast.Expression_Node) stat) {
			analyze_expr(expr);
		}
		else if (auto while_loop = cast(ast.While_Statement_Node) stat) {
			analyze_while_stat(while_loop);
		}
		else if (auto for_loop = cast(ast.For_Statement_Node) stat) {
			analyze_for_stat(for_loop);
		}
		else if (auto loop = cast(ast.Loop_Statement_Node) stat) {
			analyze_loop_stat(loop);
		}
		else if (auto if_stat = cast(ast.If_Statement_Node) stat) {
			analyze_if_stat(if_stat);
		}
		else if (auto call = cast(ast.Call_Node) stat) {
			analyze_call(call);
		}
		else if (auto ret = cast(ast.Return_Statement_Node) stat) {
			if (ret.value !is null) {
				analyze_expr(ret.value);
			}
		}
		else if (auto match = cast(ast.Switch_Statement_Node) stat) {
			resolve_match(match);
		}
		else if (auto structure_destructure = cast(ast.Structure_Destructuring_Statement_Node) stat) {
			resolve_structure_destructure(structure_destructure);
		}
		else if (auto eval = cast(ast.Block_Expression_Node) stat) {
			// TODO NOP
		}
		else if (auto next = cast(ast.Next_Statement_Node) stat) {
			// NOP
		}
		else if (auto brk = cast(ast.Break_Statement_Node) stat) {
			// NOP
		}
		else if (auto defer = cast(ast.Defer_Statement_Node) stat) {
			visit_stat(defer.stat);
		}
		else if (cast(ast.Else_Statement_Node) stat) {
			assert(0);
		}
		else if (cast(ast.Else_If_Statement_Node) stat) {
			assert(0);
		}
		else if (auto block = cast(ast.Block_Node) stat) {
			// TODO
			// i feel like this is not supposed to be here
			visit_block(block);
		}
		else {
			this.log(Log_Level.Error, "unhandled statement " ~ to!string(stat), " ... ", to!string(typeid(stat)),
				"\n", logger.blame_token(stat.get_tok_info()));
		}
	}

	override void execute(ref Module mod, string sub_mod_name, AST as_tree) {
		this.mod = mod;
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
