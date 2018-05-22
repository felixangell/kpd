module sema.top_level_name_resolve;

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

class Top_Level_Name_Resolve_Pass : Top_Level_Node_Visitor, Semantic_Pass {
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

	void resolve(ast.Type_Node tn) {
		if (auto structure = cast(Structure_Type_Node) tn) {
			resolve(structure);
		}
		else if (auto type_path = cast(Type_Path_Node) tn) {
			resolve_type_path(type_path);
		}
		else if (auto ptr = cast(Pointer_Type_Node) tn) {
			resolve(ptr.base_type);
		}
		else if (auto arr = cast(Array_Type_Node) tn) {
			resolve(arr.base_type);
		}
		else if (auto tuple = cast(Tuple_Type_Node) tn) {
			foreach (type; tuple.types) {
				resolve(type);
			}
		}
		else if (auto func = cast(Function_Type_Node) tn) {
			if (func.return_type !is null) {
				resolve(func.return_type);
			}
			foreach (p; func.params) {
				resolve(p.type);
			}
			if (func.recv !is null) {
				resolve(func.recv.type);
			}
		}
		else {
			writeln("unhandled!!? ", to!string(typeid(tn)));
		}
	}

	void resolve(ast.Structure_Type_Node nt) {
		foreach (field; nt.fields) {
			resolve(field.type);
		}
	}

	override void analyze_named_type_node(Named_Type_Node nt) {
		resolve(nt.type);
	}

	override void analyze_function_node(Function_Node f) {}

	override void analyze_var_stat_node(Variable_Statement_Node var) {}

	override void visit_stat(Statement_Node stat) {
	}

	void execute(ref Module mod, string sub_mod_name, AST as_tree) {
		this.mod = mod;
		foreach (node; as_tree) {
			if (node !is null) {
				super.process_node(node);
			}
		}
	}

	override string toString() const {
		return "top-level-name-resolve-pass";
	}
}