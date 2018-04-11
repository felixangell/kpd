module parse.parser;

import std.stdio;
import std.conv;
import std.range.primitives : back;

import grammar;
import krug_module;
import compilation_phase;
import ast;
import tok;
import keyword;

import logger;
import colour;
import sema.type : PRIMITIVE_TYPES;

static Token EOF_TOKEN;

static this() {
	EOF_TOKEN = new Token("<EOF>", Token_Type.EOF);
}

// a stack that keeps track of
// the branches (if, else if, else)
// for error checks
class Branch_Tracker {
	Branch_Tracker parent;
	ast.Statement_Node[] buffer;

	this() {
		this.parent = null;
	}

	this(Branch_Tracker parent) {
		this.parent = parent;
	}
}

class Parser : Compilation_Phase {
	Token[] toks;
	uint pos = 0;

	// when we enter a new scope this is cleared.
	Branch_Tracker curr_branch_ctx;

	this(Token[] toks) {
		this.toks = toks;
	}

	ast.Node[] parse() {
		ast.Node[] nodes;
		while (has_next()) {
			ast.Node node = parse_node();
			if (node !is null) {
				nodes ~= node;

				// TODO: we can do a better check here
				// rather than a simple expect.
				if (cast(Semicolon_Stat) node) {
					expect(";");
				}
			}
		}
		return nodes;
	}

	Token[] expect(Token_Type[] types) {
		Token[] toks;
		foreach (t; types) {
			toks ~= expect(t);
		}
		return toks;
	}

	Token[] expect(string[] lexemes) {
		Token[] toks;
		foreach (s; lexemes) {
			toks ~= expect(s);
		}
		return toks;
	}

	Token expect(string str) {
		if (!peek().cmp(str)) {
			logger.error(peek(), "Expected '" ~ str ~ "', found: '" ~ to!string(peek()) ~ "'");
			assert(0);
		}
		return consume();
	}

	Token expect(Token_Type type) {
		if (!peek().cmp(type)) {
			Token_Type other_type = peek().type;
			logger.error(peek(), "Expected '" ~ to!string(
					type) ~ "', found token of type '" ~ to!string(peek().type) ~ "'");
			assert(0);
		}
		return consume();
	}

	// skips a module load
	// #load, etc. these are handled elsewhere
	// and are disposed from the AST.
	void skip_module_load() {
		auto name = expect(keyword.Load_Directive);
		expect(Token_Type.Identifier);

		// module_access
		if (!peek().cmp("::")) {
			return;
		}
		consume();

		// not accessing a variety of
		// symbols, just one so expect
		// a single symbol and DIP
		if (!peek().cmp("{")) {
			expect(Token_Type.Identifier);
			return;
		}

		expect("{");
		for (int idx; !peek().cmp("}"); idx++) {
			if (idx > 0) {
				expect(",");
			}

			consume();
		}
		expect("}");
	}

	void recovery_skip(string value) {
		while (has_next() && !peek().cmp(value)) {
			consume();
		}
	}

	ast.Structure_Type_Node parse_structure_type(bool with_keyword = true) {
		// bit of a hack!
		if (with_keyword) {
			if (!peek().cmp(keyword.Structure)) {
				return null;
			}
			expect(keyword.Structure);
		}

		expect("{");

		auto structure_type_node = new Structure_Type_Node;
		for (int i = 0; has_next() && !peek().cmp("}"); i++) {
			auto name = expect(Token_Type.Identifier);

			auto type = parse_type();
			if (type is null) {
				logger.error(peek(), "expected type in structure field, found: ");
				recovery_skip("}");
				break;
			}

			Expression_Node value;
			if (peek().cmp("=")) {
				consume();
				value = parse_expr();
				if (value is null) {
					logger.error(peek(), "expected value after assignment operator in structure field: ");
					recovery_skip("}");
					break;
				}
			}

			structure_type_node.add_field(name, type, value);

			if (!peek().cmp("}")) {
				expect(",");
			}
			else {
				// allow a trailing comma.
				if (peek().cmp(",")) {
					consume();
				}
			}
		}
		expect("}");
		return structure_type_node;
	}

	ast.Function_Type_Node parse_func_type() {
		if (!peek().cmp(keyword.Function)) {
			return null;
		}
		expect(keyword.Function);

		auto func_type = new Function_Type_Node;

		expect("(");
		for (int i = 0; has_next() && !peek().cmp(")"); i++) {
			bool mutable = mutable_check();

			auto name = expect(Token_Type.Identifier);
			if (name is null) {
				logger.error(peek(), "expected argument name, found:");
			}

			auto type = parse_type();
			if (type is null) {
				logger.error(peek(), "expected argument type, found:");
			}

			func_type.add_param(name, type, mutable);

			if (peek().cmp(",")) {
				consume();
			}
			else if (!peek().cmp(")")) {
				logger.error(peek(), "expected comma after argument in function type: ");
			}
		}
		expect(")");

		func_type.return_type = parse_type();
		if (func_type.return_type is null) {
			// TODO: error here or allow it and assume void?!
		}

		return func_type;
	}

	ast.Trait_Type_Node parse_trait_type() {
		if (!peek().cmp(keyword.Trait)) {
			return null;
		}
		expect(keyword.Trait);

		auto trait_type_node = new Trait_Type_Node;

		expect("{");

		for (int i = 0; has_next() && !peek().cmp("}"); i++) {
			auto name = expect(Token_Type.Identifier);
			auto func_type = parse_func_type();
			if (func_type is null) {
				logger.error(peek(), "Expected function in trait, found: ");
				recovery_skip("}");
				break;
			}
			trait_type_node.add_attrib(name, func_type);

			// trailing comma
			expect(",");
		}

		expect("}");

		return trait_type_node;
	}

	ast.Union_Type_Node parse_union_type() {
		if (!peek().cmp(keyword.Union)) {
			return null;
		}
		expect(keyword.Union);
		expect("{");

		auto union_type_node = new Union_Type_Node;
		for (int i = 0; has_next() && !peek().cmp("}"); i++) {
			auto name = expect(Token_Type.Identifier);

			auto type = parse_type();
			if (type is null) {
				logger.error(peek(), "expected type in structure field, found: ");
				recovery_skip("}");
				break;
			}

			union_type_node.add_field(name, type);

			if (!peek().cmp("}")) {
				expect(",");
			}
			else {
				// allow a trailing comma.
				if (peek().cmp(",")) {
					consume();
				}
			}
		}
		expect("}");
		return union_type_node;
	}

	ast.Tagged_Union_Type_Node parse_enum_type() {
		if (!peek().cmp(keyword.Enum)) {
			return null;
		}
		expect(keyword.Enum);

		auto tagged_union = new Tagged_Union_Type_Node;

		expect("{");
		for (int i = 0; has_next() && !peek().cmp("}"); i++) {
			auto name = expect(Token_Type.Identifier);
			Type_Node type = null;
			switch (peek().lexeme) {
			case "{":
				type = parse_structure_type(false);
				break;
			case "(":
				type = parse_tuple_type();
				break;
			default:
				break;
			}

			tagged_union.add_field(name, type);

			if (!peek().cmp("}")) {
				expect(",");
			}
			else {
				// allow a trailing comma.
				if (peek().cmp(",")) {
					consume();
				}
			}
		}
		expect("}");

		return tagged_union;
	}

	ast.Pointer_Type_Node parse_pointer_type() {
		if (!peek().cmp("*")) {
			return null;
		}
		expect("*");
		auto type = parse_type();
		if (type is null) {
			logger.error(peek(), "expected type after pointer, found:");
			return null;
		}
		return new Pointer_Type_Node(type);
	}

	ast.Tuple_Type_Node parse_tuple_type() {
		if (!peek().cmp("(")) {
			return null;
		}
		expect("(");

		auto tuple_type = new Tuple_Type_Node;
		for (int i = 0; has_next() && !peek().cmp(")"); i++) {
			auto type = parse_type();
			if (type is null) {
				logger.error(peek(), "tuple expects type, found:");
				recovery_skip(")");
				break;
			}
			tuple_type.types ~= type;

			// TODO: enforce commas properly.
			if (peek().cmp(",")) {
				consume();
			}
		}
		expect(")");
		return tuple_type;
	}

	ast.Array_Type_Node parse_array_type() {
		if (!peek().cmp("[")) {
			return null;
		}
		auto start = expect("[");
		auto type = parse_type();
		if (type is null) {
			logger.error(peek(), "expected type in array type: ");
			recovery_skip("]");
		}
		auto a = new Array_Type_Node(type);

		if (peek().cmp(";")) {
			consume();
			a.value = parse_expr();
			if (a.value is null) {
				logger.error(peek(), "expected array length: ");
				recovery_skip("]");
			}
		}

		auto end = expect("]");
		a.set_tok_info(start, end);
		return a;
	}

	ast.Slice_Type_Node parse_slice_type() {
		if (!peek().cmp("&")) {
			return null;
		}
		expect(["&", "["]);
		auto type = parse_type();
		if (type is null) {
			logger.error(peek(), "expected type in array type: ");
			recovery_skip("]");
		}
		expect("]");
		return new Slice_Type_Node(type);
	}

	ast.Type_Path_Node parse_type_path() {
		if (!peek().cmp(Token_Type.Identifier)) {
			return null;
		}

		Token start = peek();

		auto res = new Type_Path_Node;
		while (peek().cmp(Token_Type.Identifier)) {
			res.values ~= consume();
			if (!peek().cmp(".")) {
				break;
			}
			expect(".");
		}

		res.set_tok_info(start, res.values[res.values.length-1]);
		return res;
	}

	ast.Type_Node parse_type() {
		Generic_Set sigils;

		// TODO: handle non parenthesis type sigil thingies
		if (peek().cmp("!")) {
			expect("!");

			if (peek().cmp("(")) {
				expect("(");

				for (int idx = 0; has_next() && !peek().cmp(")"); idx++) {
					if (idx > 0) {
						expect(",");
					}
					sigils ~= parse_generic_sigil();
				}

				expect(")");
			} else {
				// no parenthesis, expect at least ONE
				// generic sigil
				sigils ~= parse_generic_sigil();
			}
		}

		Token start = peek();

		ast.Type_Node type;

		switch (peek().lexeme) {
		case keyword.Structure:
			type = parse_structure_type();
			break;
		case keyword.Trait:
			type = parse_trait_type();
			break;
		case keyword.Union:
			type = parse_union_type();
			break;
		case keyword.Enum:
			type = parse_enum_type();
			break;
		case keyword.Function:
			type = parse_func_type();
			break;
		case "&":
			type = parse_slice_type();
			break;
		case "[":
			type = parse_array_type();
			break;
		case "(":
			type = parse_tuple_type();
			break;
		case "*":
			type = parse_pointer_type();
			break;
		default:
			break;
		}

		// we havent got a type
		// it might be a primitive
		if (type is null) {
			if (peek().lexeme in PRIMITIVE_TYPES) {
				Token prim_type_tok = consume();
				type = new Primitive_Type_Node(prim_type_tok);
				type.set_tok_info(prim_type_tok);
			}
			else {
				// not a primitive, not a type earlier
				// let's try a type path.
				type = parse_type_path();				
			}
		}

		// we only complain if we have
		// parse generic sigls because
		// the type here not being parsed is
		// perfectly ok behaviour.
		if (type is null && sigils !is null) {
			auto curr = peek();
			logger.fatal("Failed to parse type:\n", blame_token(curr));
		}

		// apply the sigils if we can
		if (type !is null) {
			type.sigils = sigils;
	
			// hopefully this doesnt fuck with parse_type_path
			type.set_tok_info(start, peek());
		}

		return type;
	}

	ast.Named_Type_Node parse_named_type() {
		if (!peek().cmp(keyword.Type)) {
			return null;
		}
		expect(keyword.Type);

		auto name = expect(Token_Type.Identifier);
		auto type = parse_type();
		if (type is null) {
			logger.error(peek(), "expected a type to bind name to, found: ");
			recovery_skip(";"); // FIXME ?
			return null;
		}

		return new Named_Type_Node(name, type);
	}

	ast.Function_Parameter parse_func_param() {
		bool mutable = false;
		if (peek().cmp(keyword.Mut)) {
			mutable = true;
			consume();
		}
		auto name = expect(Token_Type.Identifier);
		auto type = parse_type();
		return new Function_Parameter(mutable, name, type);
	}

	ast.Unary_Expression_Node parse_unary_expr(bool comp_allowed) {
		if (!is_unary_op(peek().lexeme)) {
			return null;
		}
		auto op = consume();
		auto right = parse_left(comp_allowed);
		if (right is null) {
			logger.error(peek(), "Expected expression after unary operand: \n");
			// how do we recover from this?!
		}
		return new Unary_Expression_Node(op, right);
	}

	ast.Paren_Expression_Node parse_paren_expr() {
		if (!peek().cmp("(")) {
			return null;
		}
		auto start = expect("(");
		auto expr = parse_expr();
		if (expr is null) {
			logger.error(peek(), "Expected an expression inside of parenthesis expression, found:");
			recovery_skip(")");
		}
		auto end = expect(")");

		auto paren = new Paren_Expression_Node(expr);
		paren.set_tok_info(start, end);
		return paren;
	}

	ast.Slice_Expression_Node parse_slice(Expression_Node left) {
		expect(":");
		auto right = parse_expr();
		if (right is null) {
			logger.error(peek(), "slice expected end?!!!!!");
			return null;
		}
		return new Slice_Expression_Node(left, right);
	}

	ast.Call_Node parse_call(Expression_Node left) {
		auto node = new Call_Node(left);

		// parse generic parameters.
		if (peek().cmp("!")) {
			consume();

			// multiple params
			if (peek().cmp("(")) {
				consume();

				for (int i = 0; has_next() && !peek().cmp(")"); i++) {
					if (i > 0) {
						expect(",");
					}

					node.generic_params ~= parse_type_path();
				}

				expect(")");
			}
			else {
				// single param
				node.generic_params ~= parse_type_path();
			}
		}

		expect("(");

		for (int i = 0; has_next() && !peek().cmp(")"); i++) {
			// these are for annotations, and are erased
			// these simply exist for reading the code.
			// one example would be:
			// world.get_player(name : "Felix");
			if (peek(1).cmp(":")) {
				expect(Token_Type.Identifier);
				expect(":");
			}

			auto expr = parse_expr();
			if (expr is null) {
				logger.error(peek(), "expected an expression in argument list, found: ");
				break;
			}
			node.args ~= expr;

			if (peek().cmp(",")) {
				consume();
			}
		}
		expect(")");

		return node;
	}

	ast.Expression_Node parse_operand() {
		Token curr = peek();

		if (curr.cmp("(")) {
			return parse_paren_expr();
		}

		switch (curr.lexeme) {
		case keyword.Size_Of:
		case keyword.Len_Of:
		case keyword.Type_Of:
			auto op = consume();
			if (!peek().cmp("(")) {
				logger.error(peek(), "expected paren expr, found: ");
			}
			return new Unary_Expression_Node(op, parse_paren_expr());
		default:
			break;
		}

		// boolean literal
		switch (curr.lexeme) {
		case keyword.True_Constant:
		case keyword.False_Constant:
			return new Boolean_Constant_Node(consume());
		default:
			break;
		}

		// other literal
		switch (curr.type) {
		case Token_Type.String:
			return new String_Constant_Node(consume());
		case Token_Type.CString:
			auto str = new String_Constant_Node(consume());
			str.type = String_Type.C_STYLE;
			return str;
		case Token_Type.Rune:
			return new Rune_Constant_Node(consume());
		case Token_Type.Floating_Point_Literal:
			return new Float_Constant_Node(consume());
		case Token_Type.Integer_Literal:
			return new Integer_Constant_Node(consume());
		case Token_Type.Identifier:
			return parse_path(new Symbol_Node(consume()));
		default:
			break;
		}

		return null;
	}

	ast.Generic_Sigil parse_generic_sigil() {
		Generic_Sigil sigil;
		sigil.name = expect(Token_Type.Identifier);
		if (peek().cmp(":")) {
			consume();

			while (has_next()) {
				sigil.restrictions ~= parse_type_path();
				if (!peek().cmp("+")) {
					break;
				}
				expect("+");
			}
		}
		return sigil;
	}

	ast.Index_Expression_Node parse_index_expr(Expression_Node left) {
		auto start = expect("[");
		auto index = parse_expr();
		if (index is null) {
			logger.error(peek(), "expected indexing expression, found: ");
			recovery_skip("]");
		}
		auto end = expect("]");
		
		auto result = new Index_Expression_Node(left, index);
		result.set_tok_info(start, end);
		return result;
	}

	// FIXME this is really weird and we have some
	// crazy hacks to make things parse properly.
	ast.Expression_Node parse_path(Expression_Node left) {
		auto pan = new Path_Expression_Node;

		auto start = peek();

		// append the left as a value of the path
		pan.values ~= left;

		do {
			if (!has_next() || !peek().cmp(".")) {
				break;
			}
			expect(".");

			auto expr = parse_expr();
			if (expr is null) {
				logger.error(peek(), "expected expression in path: ");
			}

			// we have to re-write the binary expression so that
			// we just the left into the path, and then we
			// move it into a new binary expr
			if (auto binary = cast(Binary_Expression_Node) expr) {
				// flatten if necessaru
				if (auto path = cast(Path_Expression_Node) binary.left) {
					foreach (val; path.values) {
						pan.values ~= val;
					}
				}
				else {
					pan.values ~= binary.left;
				}

				auto result = new Binary_Expression_Node(pan, binary.operand, binary.right);
				result.set_tok_info(start, peek());
				return result;
			}

			// if we parse another path, flatten it into this 
			// path
			if (auto path = cast(Path_Expression_Node) expr) {
				foreach (val; path.values) {
					pan.values ~= val;
				}
			}
			else {
				pan.values ~= expr;
			}
		}
		while (has_next());

		pan.set_tok_info(start, peek());
		return pan;
	}

	ast.Expression_Node parse_primary_expr(bool comp_allowed) {
		if (is_unary_op(peek().lexeme)) {
			return parse_unary_expr(comp_allowed);
		}

		auto left = parse_operand();
		if (left is null) {
			return null;
		}

		// TODO: handle generic arguments

		Expression_Node result;

		auto tok = peek();
		switch (tok.lexeme) {
		case "[":
			result = parse_index_expr(left);
			break;
		case "!":
			result = parse_call(left);
			break;
		case "(":
			result = parse_call(left);
			break;
		case ":":
			result = parse_slice(left);
			break;
		case ".":
			return parse_path(left);
		default:
			break;
		}

		if (result is null) {
			return left;
		}

		// TODO: handle indexing expr
		// TODO: handle "access" path expr foo.bar.baz
		// TODO: handle composites?
		// TODO: handle calls, e.g. foo()

		// path!?
		return result;
	}

	ast.Expression_Node parse_left(bool comp_allowed = false) {
		auto expr = parse_primary_expr(comp_allowed);
		if (expr !is null) {
			return expr;
		}
		return parse_unary_expr(comp_allowed);
	}

	ast.Expression_Node parse_bin_op(int last_prec, Expression_Node left, bool comp_allowed) {
		while (has_next()) {
			auto prec = get_op_prec(peek().lexeme);

			// what?!
			if (is_binary_op(peek().lexeme) && peek(1).cmp(";")) {
				logger.warn("just letting you know something weird happened in parse_bin_op");
				return left;
			}

			if (prec < last_prec) {
				return left;
			}

			auto operator = consume();

			ast.Expression_Node right = null;
			if (operator.lexeme == "as") {
				auto type = parse_type();
				// handle errors...
				left = new Cast_Expression_Node(left, type);
				continue;
			} 
			else {
				right = parse_primary_expr(comp_allowed);
			}

			if (right is null) {
				return null;
			}

			// TODO: handle this properly as it's weird behaviour
			// and should in theory not parse!
			// e.g. a + b <EOF>
			if (!has_next()) {
				return new Binary_Expression_Node(left, operator, right);
			}

			int next_prec = get_op_prec(peek().lexeme);
			if (prec < next_prec) {
				right = parse_bin_op(prec + 1, right, comp_allowed);
				if (right is null) {
					return null;
				}
			}

			left = new Binary_Expression_Node(left, operator, right);
		}
		return left;
	}

	ast.Lambda_Node parse_lambda() {
		if (!peek().cmp(keyword.Function)) {
			return null;
		}
		// NOTE: the keyword is handled in parse_func_type

		auto func_type = parse_func_type();
		if (func_type is null) {
			logger.error(peek(), "expected lambda, found: \n");
			return null;
		}

		auto block = parse_block();
		if (block is null) {
			logger.error(peek(), "expected block after lambda: \n");
		}

		return new Lambda_Node(func_type, block);
	}

	ast.Expression_Node parse_expr(bool comp_allowed = false) {
		// TODO: parsing composite expressions?

		Token start = peek();

		if (peek().cmp(keyword.Eval) && peek(1).cmp("{")) {
			expect(keyword.Eval);
			auto result = new Block_Expression_Node(parse_block());
			result.set_tok_info(start, peek());
			return result;
		}

		// lambda
		if (peek().cmp(keyword.Function)) {
			auto result = parse_lambda();
			result.set_tok_info(start, peek());
			return result;
		}

		auto left = parse_left(comp_allowed);
		if (left is null) {
			return null;
		}

		if (!has_next()) {
			// TODO: handle this properly for when it does happen
			// this should never happen, but just in case.
			left.set_tok_info(start, peek());
			return left;
		}

		// not a binary expression so we'll
		// return the left expression
		if (!is_binary_op(peek().lexeme)) {
			left.set_tok_info(start, peek());
			return left;
		}

		auto bin = parse_bin_op(0, left, comp_allowed);
		bin.set_tok_info(start, peek());
		return bin;
	}

	ast.Structure_Destructuring_Statement_Node parse_structure_destructure() {
		if (!peek().cmp("{")) {
			return null;
		}
		consume();

		auto node = new Structure_Destructuring_Statement_Node;
		for (int i = 0; has_next() && !peek().cmp("}"); i++) {
			node.values ~= expect(Token_Type.Identifier);

			// TODO: handle
			if (peek().cmp(",")) {
				consume();
			}
		}
		consume();

		expect("=");
		node.rhand = parse_expr();
		if (node.rhand is null) {
			logger.error(peek(), "expected value after assignment operator:\n");
			recovery_skip(";");
		}

		return node;
	}

	ast.Tuple_Destructuring_Statement_Node parse_tuple_destructure() {
		if (!peek().cmp("(")) {
			return null;
		}
		consume();

		auto node = new Tuple_Destructuring_Statement_Node;
		for (int i = 0; has_next() && !peek().cmp(")"); i++) {
			node.values ~= expect(Token_Type.Identifier);

			// TODO: handle
			if (peek().cmp(",")) {
				consume();
			}
		}
		consume();

		expect("=");
		node.rhand = parse_expr();
		if (node.rhand is null) {
			logger.error(peek(), "expected value after assignment operator:\n");
			recovery_skip(";");
		}

		return node;
	}

	ast.Statement_Node parse_var() {
		if (!peek().cmp(keyword.Let) && !peek().cmp(keyword.Mut)) {
			return null;
		}
		bool mutable = consume().cmp(keyword.Mut);

		auto tok = peek();
		switch (tok.lexeme) {
		case "{":
			return parse_structure_destructure();
		case "(":
			return parse_tuple_destructure();
		default:
			break;
		}

		// TODO: destructuring statements!
		// let {a, b, c, ...} = some_struct
		// let (a, b, c, ...) = some_tuple

		Token name = expect(Token_Type.Identifier);

		Type_Node type = null;
		if (!peek().cmp("=")) {
			type = parse_type();
		}

		// if there is no type and the next operator is not an equal
		// or a semi-colon symbol, that means that we have some weird
		// input - throw an error!
		if (type is null && !(peek().cmp("=") || peek().cmp(";"))) {
			logger.error(peek(), "expected type in variable binding, found:");
			recovery_skip(";");
		}

		auto var = new Variable_Statement_Node(name, type, mutable);

		if (peek().cmp("=")) {
			consume();

			var.value = parse_expr();
			if (var.value is null) {
				logger.error(peek(), "expected value after assignment operator, found:");
				recovery_skip(";");
			}
		}

		return var;
	}

	ast.Return_Statement_Node parse_return() {
		if (!peek().cmp(keyword.Return)) {
			return null;
		}
		expect(keyword.Return);

		auto val = parse_expr();
		if (val is null && !peek().cmp(";")) {
			logger.error(peek(), "expected expression or terminating semi-colon, found:");
			return null;
		}
		return new Return_Statement_Node(val);
	}

	ast.Break_Statement_Node parse_break() {
		if (!peek().cmp(keyword.Break)) {
			return null;
		}
		expect(keyword.Break);
		return new Break_Statement_Node();
	}

	ast.Next_Statement_Node parse_next() {
		if (!peek().cmp(keyword.Next)) {
			return null;
		}
		expect(keyword.Next);
		return new Next_Statement_Node();
	}

	ast.Yield_Statement_Node parse_yield() {
		if (!peek().cmp(keyword.Yield)) {
			return null;
		}
		expect(keyword.Yield);

		auto value = parse_expr();
		if (value is null) {
			logger.error(peek(), "yield stat expects an expression, found:");
		}
		return new Yield_Statement_Node(value);
	}

	ast.Defer_Statement_Node parse_defer() {
		if (!peek().cmp(keyword.Defer)) {
			return null;
		}
		expect(keyword.Defer);

		auto stat = parse_stat();
		if (stat is null) {
			logger.error(peek(), "expected statement after defer, found:");
			return null;
		}
		return new Defer_Statement_Node(stat);
	}

	ast.While_Statement_Node parse_while() {
		if (!peek().cmp(keyword.While)) {
			return null;
		}
		expect(keyword.While);

		auto cond = parse_expr();
		if (cond is null) {
			logger.error(peek(), "expected condition in while loop, found:");
		}

		auto block = parse_block();
		if (block is null) {
			logger.error(peek(), "expected block after while, found:");
		}

		return new While_Statement_Node(cond, block);
	}

	// for var; condition; step {}
	/*
		i dont like the variable
	

		for i < 10; i = i + 1 {
	
		}
	*/
	ast.Loop_Statement_Node parse_for() {
		logger.error(peek(), "unimplemented");
		assert(0);
	}

	ast.Match_Statement_Node parse_match() {
		if (!peek().cmp(keyword.Match)) {
			return null;
		}
		expect(keyword.Match);

		auto condition = parse_expr();
		if (condition is null) {
			logger.error(peek(), "expected condition in match criteria:");
		}

		Match_Arm_Node[] arms;

		expect("{");
		while (has_next() && !peek().cmp("}")) {
			auto arm = new Match_Arm_Node;

			while (has_next() && !peek().cmp("{")) {
				// TODO default
				// peek.cmp("_")

				auto val = parse_expr();
				if (val is null) {
					logger.error(peek(), "fixme");
					break;
				}

				arm.expressions ~= val;

				// TODO trailing commas etc
				if (peek().cmp(",")) {
					consume();
				}
			}

			arm.block = parse_block();
			if (arm.block is null) {
				logger.error(peek(), "expected block after match arm");
				break;
			}

			arms ~= arm;

			// TODO trailing commas
			if (peek().cmp(",")) {
				consume();
			}
		}
		expect("}");

		return new Match_Statement_Node(condition, arms);
	}

	ast.Loop_Statement_Node parse_loop() {
		if (!peek().cmp(keyword.Loop)) {
			return null;
		}
		expect(keyword.Loop);

		auto block = parse_block();
		if (block is null) {
			logger.error(peek(), "expected block after while, found:");
		}

		return new Loop_Statement_Node(block);
	}

	ast.If_Statement_Node parse_if() {
		if (!peek().cmp(keyword.If)) {
			return null;
		}
		expect(keyword.If);

		auto cond = parse_expr();
		if (cond is null) {
			logger.error(peek(), "expected condition in if construct, found:");
		}

		auto block = parse_block();
		if (block is null) {
			logger.error(peek(), "expected block after if, found:");
		}

		auto iff = new If_Statement_Node(cond, block);
		curr_branch_ctx.buffer ~= iff;
		return iff;
	}

	ast.Else_Statement_Node parse_else() {
		if (!peek().cmp(keyword.Else)) {
			return null;
		}
		auto start = expect(keyword.Else);

		auto block = parse_block();
		if (block is null) {
			logger.error(peek(), "expected block after else, found:");
		}

		// else if must have an if or an else if
		// before it
		if (curr_branch_ctx !is null) {
			if (curr_branch_ctx.buffer.length == 0) {
				logger.error(start, "else must follow an if or an else if statement.");
			}
			else {
				// check that the last statement
				// was either an else if or an if
				auto last = curr_branch_ctx.buffer.back;
				if (!(cast(If_Statement_Node)last || cast(Else_If_Statement_Node)last)) {
					logger.error(start, "else must follow an if or an else if statement.");
				}
			}
		}

		auto e = new Else_Statement_Node(block);
		curr_branch_ctx.buffer ~= e;
		return e;
	}

	ast.Else_If_Statement_Node parse_elif() {
		if (!peek().cmp(keyword.Else) && !peek(1).cmp(keyword.If)) {
			return null;
		}
		auto start = expect(["else", "if"]);

		auto cond = parse_expr();
		if (cond is null) {
			logger.error(peek(), "expected condition for else-if-construct, found:");
		}

		auto block = parse_block();
		if (block is null) {
			logger.error(peek(), "expected block for else-if-construct, found:");
		}

		// else if must have an if or an else if
		// before it
		if (curr_branch_ctx !is null) {
			if (curr_branch_ctx.buffer.length == 0) {
				logger.error(start[0], "else if must follow an if or an else if statement.");
			}
			else {
				// check that the last statement
				// was either an else if or an if
				auto last = curr_branch_ctx.buffer.back;
				if (!(cast(If_Statement_Node)last || cast(Else_If_Statement_Node)last)) {
					logger.error(start[0], "else if must follow an if or an else if statement.");
				}
			}
		}

		return new Else_If_Statement_Node(cond, block);
	}

	ast.Statement_Node parse_stat() {
		Token tok = peek();

		ast.Statement_Node result = null;
		switch (tok.lexeme) {
		case keyword.Let:
		case keyword.Mut:
			result = parse_var();
			break;
		case keyword.Match:
			result = parse_match();
			break;
		case keyword.Defer:
			result = parse_defer();
			break;
		case keyword.While:
			result = parse_while();
			break;
		case keyword.If:
			result = parse_if();
			break;
		case keyword.Else:
			// ELSE IF!
			if (peek(1).cmp(keyword.If)) {
				result = parse_elif();
			}
			else {
				result = parse_else();
			}
			break;
		case keyword.For:
			result = parse_for();
			break;
		case keyword.Loop:
			result = parse_loop();
			break;
		case keyword.Yield:
			result = parse_yield();
			break;
		case keyword.Return:
			result = parse_return();
			break;
		case keyword.Break:
			result = parse_break();
			break;
		case keyword.Next:
			result = parse_next();
			break;
		case "{":
			result = parse_block();
			break;
		default:
			break;
		}

		if (result !is null) {
			result.set_tok_info(tok, peek());
			return result;
		}

		Token start = peek();

		// FIXME
		// fuck it, try parsing an expression.
		auto val = parse_expr();
		if (val is null) {
			return null;
		}

		expect(";");
		val.set_tok_info(start, peek());
		return val;
	}

	ast.Block_Node parse_block() {
		if (!peek().cmp("{")) {
			return null;
		}
		expect("{");

		auto prev = curr_branch_ctx;
		curr_branch_ctx = new Branch_Tracker(prev);

		Block_Node block = new Block_Node();
		for (int i = 0; has_next() && !peek().cmp("}"); i++) {
			Statement_Node stat = parse_stat();
			if (stat is null) {
				logger.error(peek(), "Expected statement, found: ");
				break;
			}
			block.statements ~= stat;
			if (cast(Semicolon_Stat) stat) {
				expect(";");
			}
		}

		// restore the previous branch
		// we were tracking
		if (curr_branch_ctx.parent !is null) {
			curr_branch_ctx = curr_branch_ctx.parent;
		}

		expect("}");
		return block;
	}

	bool mutable_check() {
		bool mutable = false;
		if (peek().cmp(keyword.Mut)) {
			consume();
			mutable = true;
		}
		return mutable;
	}

	ast.Function_Node parse_func() {
		if (!peek().cmp(keyword.Function)) {
			return null;
		}
		expect(keyword.Function);

		Function_Node func = new Function_Node();

		// function receiver parsing!
		if (peek().cmp("(")) {
			consume();

			bool mutable = mutable_check();
			auto name = expect(Token_Type.Identifier);
			auto parent_type = parse_type();
			if (parent_type is null) {
				logger.error(peek(), "expected parent type of func receiver, found:");
				recovery_skip(")");
			}

			func.func_recv = new Variable_Statement_Node(name, parent_type, mutable);

			expect(")");
		}

		func.name = expect(Token_Type.Identifier);

		// parse the generic sigils.
		if (peek().cmp("!")) {
			expect("!");
			expect("(");

			for (int idx = 0; has_next() && !peek().cmp(")"); idx++) {
				if (idx > 0) {
					expect(",");
				}
				func.generics ~= parse_generic_sigil();
			}

			expect(")");
		}

		// TODO: we dont use the Function Type here... hmm?

		// func params
		expect("(");
		for (int idx = 0; has_next() && !peek().cmp(")"); idx++) {
			if (idx > 0) {
				expect(",");
			}

			auto param = parse_func_param();
			if (param) {
				func.params ~= param;
			}
		}
		expect(")");

		func.return_type = parse_type();

		if (peek().cmp("{")) {
			func.func_body = parse_block();
			return func;
		}

		expect(";");
		return func;
	}

	Attribute[string] parse_directives() {
		expect(keyword.Directive_Symbol);

		Attribute[string] dir;

		auto curr = peek();
		if (curr.cmp(keyword.Load_Directive)) {
			skip_module_load();
			return dir;
		}

		// illegal, throw some error!
		if (!curr.cmp("{")) {
			return dir;
		}
		expect("{");

		for (int j = 0; has_next() && !peek().cmp("}"); j++) {
			if (j > 0) {
				expect(",");
			}

			auto attrib = new Attribute(expect(Token_Type.Identifier));
			if (peek().cmp("(")) {
				consume();

				for (int i = 0; has_next() && !peek.cmp(")"); i++) {
					if (i > 0) {
						expect(",");
					}

					auto val = new Attribute_Value(expect(Token_Type.Identifier));
					if (peek.cmp("=")) {
						consume();
						val.value = consume();
					}

					attrib.values ~= val;
				}
				expect(")");
			}

			logger.verbose("--- Parsed attribute ", attrib.name.lexeme);
			dir[attrib.name.lexeme] = attrib;
		}
		expect("}");

		return dir;
	}

	ast.Node parse_node() {
		Attribute[string] dirs = null;
		if (peek().cmp(keyword.Directive_Symbol)) {
			dirs = parse_directives();
		}

		Node result = null;

		auto start = peek();

		switch (peek().lexeme) {
		case keyword.Type:
			result = parse_named_type();
			break;
		case keyword.Function:
			result = parse_func();
			break;
		case keyword.Let:
		case keyword.Mut:
			result = parse_var();
			break;
		default:
			logger.verbose("unhandled top level node parse_node " ~ to!string(peek()));
			return null;
		}

		// attach the directives we
		// parsed before the node to the node
		result.set_attribs(dirs);
		result.set_tok_info(start, peek());

		return result;
	}

	Token peek(uint offs = 0) {
		if (pos + offs >= toks.length) {
			return EOF_TOKEN;
		}
		return toks[pos + offs];
	}

	Token consume() {
		return toks[pos++];
	}

	bool has_next() {
		return pos < toks.length;
	}

	string get_name() {
		return "Parser";
	}
}
