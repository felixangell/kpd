module sema.visitor;

import ast;
import logger;
import sema.symbol;
import sema.infer : Type_Environment;
import krug_module;

import std.stdio;
import std.conv;

class AST_Visitor {
	abstract void process_node(ast.Node node);
}

class Top_Level_Node_Visitor : AST_Visitor {
	protected Symbol_Table curr_sym_table;

	abstract void analyze_named_type_node(ast.Named_Type_Node);
	abstract void analyze_function_node(ast.Function_Node);
	abstract void analyze_var_stat_node(ast.Variable_Statement_Node);
	abstract void visit_stat(ast.Statement_Node);

	// kind of messy architecture
	// going on here but its the cleanest
	// way that works atm.
	void setup_sym_table(Module mod, string sub_mod, ref AST as_tree) {
		import object : hashOf;

		if (sub_mod in mod.sym_tables) {
			curr_sym_table = mod.sym_tables[sub_mod];
			logger.verbose(" - RESTORED SYMBOL TABLE ", to!string(curr_sym_table.id));
			return;
		}

		mod.sym_tables[sub_mod] = push_sym_table();
	}

	Symbol_Table push_sym_table() {
		auto s = new Symbol_Table(curr_sym_table);
		logger.verbose(" - PUSHED SYMBOL TABLE ", to!string(s.id));
		curr_sym_table = s;
		return s;
	}

	Symbol_Table leave_sym_table() {
		auto old = curr_sym_table;
		logger.verbose(" - POPPED SYMBOL TABLE ", to!string(old.id));
		curr_sym_table = old.outer;
		return old;
	}

	void visit_block(ast.Block_Node block, void delegate(Symbol_Table curr_stab) previsit = null, void delegate(Symbol_Table curr_stab) postvisit = null) {
		// this should ONLY happen on the first pass...
		// maybe have a check to throw an error if 
		// this occurs after the decl pass.
		if (block.sym_table is null) {
			logger.verbose("Setting up a symbol table in block");
			block.sym_table = push_sym_table();
		}

		logger.verbose("Restored symbol table ", to!string(block.sym_table.id), " entries:");
		foreach (entry; block.sym_table.symbols.byKeyValue()) {
			logger.verbose("- ", entry.key);
		}
		foreach (entry; block.sym_table.env.data.byKeyValue()) {
			logger.verbose("* ", entry.key);
		}
		logger.verbose("");

		curr_sym_table = block.sym_table;

		if (previsit !is null) {
			previsit(curr_sym_table);
		}

		foreach (stat; block.statements) {
			if (stat is null) {
				logger.warn("null statement in block? " ~ to!string(block));
				continue;
			}

			// handle nested blocks
			if (auto b = cast(Block_Node) stat) {
				visit_block(b);
			}
			else {
				visit_stat(stat);
			}
		}

		if (postvisit !is null) {
			postvisit(curr_sym_table);
		}

		leave_sym_table();
	}

	override void process_node(ast.Node node) {
		if (auto named_type_node = cast(ast.Named_Type_Node) node) {
			analyze_named_type_node(named_type_node);
		}
		else if (auto func_node = cast(ast.Function_Node) node) {
			analyze_function_node(func_node);
		}
		else if (auto var_node = cast(ast.Variable_Statement_Node) node) {
			analyze_var_stat_node(var_node);
		}
		else {
			logger.fatal("unhandled node in " ~ to!string(this) ~ " execution:\n" ~ to!string(
					node));
		}
	}
}
