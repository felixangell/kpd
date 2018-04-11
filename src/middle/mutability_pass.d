module sema.mutability;

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

class Mutability_Pass : Top_Level_Node_Visitor, Semantic_Pass {

	void analyze_sym(ast.Symbol_Node sym) {

	}

	// a = b
	// this analyzes a binary expression i.e.
	// taking a and setting it to b. here we
	// check if a is mutable or not
	void analyze_mutation(ast.Binary_Expression_Node expr) {

	}

	// here we compare arguments and check if 
	// the arguments are mutable and whether
	// that is satisfied by the function being called
	// or in other words if the function wants a mutable
	// variable or not.
	//
	// for example:
	// foo(a, b, c, d, e)
	void analyze_mutation(ast.Call_Node call) {

	}

	void analyze_expr(ast.Expression_Node expr) {
		if (auto binary = cast(ast.Binary_Expression_Node) expr) {
			if (binary.operand.lexeme == "=") {
				analyze_mutation(binary);
				return;
			}

			analyze_expr(binary.left);
			analyze_expr(binary.right);
		}
		else if (auto call = cast(ast.Call_Node) expr) {
			analyze_mutation(call);
		}
		else if (auto paren = cast(ast.Paren_Expression_Node) expr) {
			analyze_expr(paren.value);
		}
		else if (auto sym = cast(ast.Symbol_Node) expr) {
			analyze_sym(sym);
		}
		else if (auto path = cast(ast.Path_Expression_Node) expr) {
			analyze_expr(path.values[$-1]);
		}
		else if (cast(ast.Integer_Constant_Node) expr) {
			// NOP
		}
		else if (cast(ast.Float_Constant_Node) expr) {
			// NOP
		}
		else if (cast(ast.String_Constant_Node) expr) {
			// NOP
		}
		else if (cast(ast.Rune_Constant_Node) expr) {
			// NOP
		}
		else {
			writeln(" moanning about ", to!string(expr));
			this.log(Log_Level.Error, expr.get_tok_info(), "unhandled expr " ~ to!string(typeid(expr)));
		}
	}

	override void analyze_named_type_node(ast.Named_Type_Node node) {

	}

	override void analyze_let_node(ast.Variable_Statement_Node var) {
		if (var.value !is null) {
			analyze_expr(var.value);
		}
	}

	override void analyze_function_node(ast.Function_Node func) {
		if (func.func_body !is null) {
			visit_block(func.func_body);
		}
	}

	override void visit_stat(ast.Statement_Node stat) {
		if (auto var = cast(ast.Variable_Statement_Node) stat) {
			analyze_let_node(var);
		}
		else if (auto match = cast(ast.Match_Statement_Node) stat) {
			// TODO	
		}
		else if (auto expr = cast(ast.Expression_Node) stat) {
			analyze_expr(expr);
		}
		else if (auto sd = cast(ast.Structure_Destructuring_Statement_Node) stat) {
			// TODO NOP?
		}
		else {
			this.log(Log_Level.Error, stat.get_tok_info(), "unhandled statement " ~ to!string(typeid(stat)));			
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
		return "mutability-pass";
	}

}
