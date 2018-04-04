module sema.visitor;

import ast;
import logger;
import sema.symbol;
import sema.infer : Type_Environment;

import std.conv;

class AST_Visitor {
	abstract void process_node(ast.Node node);
}

// ...
private Symbol_Table[ast.Node] sym_tables;

class Top_Level_Node_Visitor : AST_Visitor {
	protected Symbol_Table curr_sym_table;

	abstract void analyze_named_type_node(ast.Named_Type_Node);
	abstract void analyze_function_node(ast.Function_Node);
	abstract void analyze_let_node(ast.Variable_Statement_Node);
	abstract void visit_stat(ast.Statement_Node);

	// kind of messy architecture
	// going on here but its the cleanest
	// way that works atm.
	void setup_sym_table(ref AST as_tree) {
		// NOTE: this is a stupid hack i dont know
		// if it works. we cant have mutable keys
		// as an associative array so instead we
		// use the first node in the AST as the key...
		// hopefully this uses some weird hash of the
		// object so its always unique? is the assumption
		// im going with here...
		if (as_tree[0] in sym_tables) {
			curr_sym_table = sym_tables[as_tree[0]];
			return;
		}
		sym_tables[as_tree[0]] = push_sym_table();
	}

	Symbol_Table push_sym_table() {
		auto s = new Symbol_Table(curr_sym_table);
		curr_sym_table = s;
		return s;
	}

	Symbol_Table leave_sym_table() {
		auto old = curr_sym_table;
		logger.verbose(" - POPPED SYMBOL TABLE ", to!string(old.id));
		curr_sym_table = old.outer;
		return old;
	}

	// stuff
	// TODO rename stuff to something better
	// the stuff delegate will run _Before_ we leave
	// the symbol table, as well as _Before_ we visit
	// any of the block statements.
	void visit_block(ast.Block_Node block, void delegate(Symbol_Table curr_stab) stuff = null) {
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

		if (stuff !is null) {
			stuff(curr_sym_table);
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
			analyze_let_node(var_node);
		}
		else {
			logger.fatal("unhandled node in " ~ to!string(this) ~ " execution:\n" ~ to!string(
					node));
		}
	}
}
