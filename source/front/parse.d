module parse.parser;

import std.stdio;
import std.conv;

import grammar;
import krug_module;
import compilation_phase;
import ast;
import keyword;

import ds.hash_set;
import err_logger;

static Token EOF_TOKEN;
static Hash_Set!string PRIMITIVE_TYPES;

static this() {
    EOF_TOKEN = new Token("<EOF>", Token_Type.EOF);
    PRIMITIVE_TYPES = new Hash_Set!string(
        "s8", "s16", "s32", "s64",
        "u8", "u16", "u32", "u64",
        "f32", "f64",
        "rune", "int", "uint",
        "bool", "void",
    );
}

class Parser : Compilation_Phase  {
	Token[] toks;
	uint pos = 0;

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
				if (cast(Semicolon_Stat)node) {
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
            err_logger.Error(peek(), "Expected '" ~ str ~ "', found: '");
            assert(0);
        }
        return consume();
    }

    Token expect(Token_Type type) {
        if (!peek().cmp(type)) {
            err_logger.Error(peek(), "Expected '" ~ to!string(type) ~ "', found:");
            assert(0);
        }
        return consume();
    }

    // TODO: this should be done better!
    void skip_dir() {
        expect(keyword.Directive_Symbol);

        auto name = expect(Token_Type.Identifier);
        switch (name.lexeme) {
        case keyword.Load_Directive:
            expect(Token_Type.Identifier);

            // module_access
            if (!peek().cmp("::")) {
                break;
            }
            consume();

            // not accessing a variety of
            // symbols, just one so expect
            // a single symbol and DIP
            if (!peek().cmp("{")) {
                expect(Token_Type.Identifier);
                break;
            }

            expect("{");
            for (int idx; !peek().cmp("}"); idx++) {
                if (idx > 0) expect(",");
                consume();
            }
            expect("}");
            break;
        default: break;
        }
    }

    void recovery_skip(string value) {
        while (has_next() && !peek().cmp(value)) {
            consume();
        }
    }

    ast.Structure_Type_Node parse_structure_type() {
        if (!peek().cmp(keyword.Structure)) {
            return null;
        }
        expect(keyword.Structure);
        expect("{");

        auto structure_type_node = new Structure_Type_Node;
        for (int i = 0; has_next() && !peek().cmp("}"); i++) {
            auto name = expect(Token_Type.Identifier);

            auto type = parse_type();
            if (type is null) {
                err_logger.Error(peek(), "expected type in structure field, found: ");
                recovery_skip("}");
                break;
            }

            Expression_Node value;
            if (peek().cmp("=")) {
                consume();
                value = parse_expr();
                if (value is null) {
                    err_logger.Error(peek(), "expected value after assignment operator in structure field: ");
                }
            }

            structure_type_node.add_field(name, type, value);

            if (!peek().cmp("}")) {
                expect(",");
            } else {
                // allow a trailing comma.
                if (peek().cmp(",")) {
                    consume();
                }
            }
        }
        expect("}");
        return structure_type_node;
    }

    ast.Type_Node parse_type() {
        Token tok = peek();

        switch (tok.lexeme) {
        case keyword.Structure:
            return parse_structure_type();
        case keyword.Trait:
            break;
        case keyword.Union: break;
        case keyword.Enum: break;
        case keyword.Function: break;
        case "&": break;
        case "[": break;
        case "(": break;
        case "*": break;
        default: break;
        }

        if (tok.lexeme in PRIMITIVE_TYPES) {
            return new Primitive_Type_Node(consume());
        }
        return null;
    }

    ast.Named_Type parse_named_type() {
        if (!peek().cmp(keyword.Type)) {
            return null;
        }
        expect(keyword.Type);

        auto name = expect(Token_Type.Identifier);
        auto type = parse_type();
        if (type is null) {
            err_logger.Error(peek(), "expected a type to bind name to, found: ");
            return null;
        }
        return new Named_Type(name, type);
    }

    ast.Function_Parameter parse_func_param() {
        bool mutable = false;
        if (peek().cmp(keyword.Mutable)) {
            mutable = true;
            consume();
        }
        auto name = expect(Token_Type.Identifier);
        auto type = parse_type();
        return Function_Parameter(mutable, name, type);
    }

    ast.Unary_Expression_Node parse_unary_expr(bool comp_allowed) {
        if (!is_unary_op(peek().lexeme)) {
            return null;
        }
        auto op = consume();
        auto right = parse_left(comp_allowed);
        if (right is null) {
            // error: unary expr expected expr after operator.
        }
        return new Unary_Expression_Node(op, right);
    }

    ast.Paren_Expression_Node parse_paren_expr() {
        if (!peek().cmp("(")) {
            return null;
        }
        expect("(");
        auto expr = parse_expr();
        if (expr is null) {
            // error: expected expr ting
        }
        expect(")");
        return new Paren_Expression_Node(expr);
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
            // TODO:
            break;
        default: break;
        }

        // boolean literal
        switch (curr.lexeme) {
        case keyword.True_Constant: case keyword.False_Constant:
            return new Boolean_Constant_Node(consume());
        default: break;
        }

        // other literal
        switch (curr.type) {
        case Token_Type.String:
            return new String_Constant_Node(consume());
        case Token_Type.Rune:
            return new Rune_Constant_Node(consume());
        case Token_Type.Floating_Point_Literal:
            return new Float_Constant_Node(consume());
        case Token_Type.Integer_Literal:
            return new Integer_Constant_Node(consume());
        default:
            err_logger.Verbose("Potentially unhandled constant " ~ to!string(peek()));
            break;
        }

        writeln("parse_operand what is " ~ to!string(peek()));
        return null;
    }

    ast.Expression_Node parse_primary_expr(bool comp_allowed) {
        auto left = parse_operand();
        if (left is null) {
            return null;
        }

        // TODO: handle generic arguments
        // TODO: handle indexing expr
        // TODO: handle "access" path expr foo.bar.baz
        // TODO: handle composites?
        // TODO: handle calls, e.g. foo()

        return left;
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
                writeln("just letting you know something weird happened in parse_bin_op");
                return left;
            }

            if (prec < last_prec) {
                return left;
            }

            auto operator = consume();
            auto right = parse_expr(comp_allowed);
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

    ast.Expression_Node parse_expr(bool comp_allowed = false) {
        // TODO: parsing composite expressions?

        if (peek().cmp(keyword.Eval) && peek(1).cmp("{")) {
            expect(keyword.Eval);
            return new Block_Expression_Node(parse_block());
        }

        // lambda

        auto left = parse_left(comp_allowed);
        if (left is null) {
            return null;
        }

        if (!has_next()) {
            // TODO: handle this properly for when it does happen
            // this should never happen, but just in case.
            return left;
        }

        // not a binary expression so we'll
        // return the left expression
        if (!is_binary_op(peek().lexeme)) {
            return left;
        }

        return parse_bin_op(0, left, comp_allowed);
    }

    ast.Variable_Statement_Node parse_let() {
        if (!peek().cmp(keyword.Let)) {
            return null;
        }
        consume();

        bool mutable = false;
        if (peek().cmp(keyword.Mutable)) {
            mutable = true;
            consume();
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
            err_logger.Error(peek(), "expected type in variable binding, found:");
        }

        auto var = new Variable_Statement_Node(name, type);
        var.mutable = mutable;

        if (peek().cmp("=")) {
            consume();

            var.value = parse_expr();
            if (var.value is null) {
                err_logger.Error(peek(), "expected value after assignment operator, found:");
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
            err_logger.Error(peek(), "expected expression or terminating semi-colon, found:");
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
            err_logger.Error(peek(), "yield stat expects an expression, found:");
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
            err_logger.Error(peek(), "expected statement after defer, found:");
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
            err_logger.Error(peek(), "expected condition in while loop, found:");
        }

        auto block = parse_block();
        if (block is null) {
            err_logger.Error(peek(), "expected block after while, found:");
        }

        return new While_Statement_Node(cond, block);
    }

    ast.Loop_Statement_Node parse_loop() {
        if (!peek().cmp(keyword.Loop)) {
            return null;
        }
        expect(keyword.Loop);

        auto block = parse_block();
        if (block is null) {
            err_logger.Error(peek(), "expected block after while:");
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
            err_logger.Error(peek(), "expected condition in if construct, found:");
        }

        auto block = parse_block();
        if (block is null) {
            err_logger.Error(peek(), "expected block after if, found:");
        }

        return new If_Statement_Node(cond, block);
    }

    ast.Else_Statement_Node parse_else() {
        if (!peek().cmp(keyword.Else)) {
            return null;
        }
        expect(keyword.Else);

        auto block = parse_block();
        if (block is null) {
            err_logger.Error(peek(), "expected block after else, found:");
        }

        return new Else_Statement_Node(block);
    }

    ast.Else_If_Statement_Node parse_elif() {
        if (!peek().cmp(keyword.Else) && !peek(1).cmp(keyword.If)) {
            return null;
        }
        expect(["else", "if"]);
        auto cond = parse_expr();
        if (cond is null) {
            err_logger.Error(peek(), "expected condition for else-if-construct, found:");
        }

        auto block = parse_block();
        if (block is null) {
            err_logger.Error(peek(), "expected block for else-if-construct, found:");
        }

        return new Else_If_Statement_Node(cond, block);
    }

    ast.Statement_Node parse_stat() {
        Token tok = peek();
        switch (tok.lexeme) {
        case keyword.Let:
            return parse_let();
        case keyword.Defer:
            return parse_defer();
        case keyword.While:
            return parse_while();
        case keyword.If:
            return parse_if();
        case keyword.Else:
            // ELSE IF!
            if (peek(1).cmp(keyword.If)) {
                return parse_elif();
            }
            return parse_else();
        case keyword.Loop:
            return parse_loop();
        case keyword.Yield:
            return parse_yield();
        case keyword.Return:
            return parse_return();
        case keyword.Break:
            return parse_break();
        case keyword.Next:
            return parse_next();
        default: break;
        }

        // FIXME
        // fuck it, try parsing an expression.
        auto val = parse_expr();
        if (val is null) {
            return null;
        }

        expect(";");
        return val;
    }

    ast.Block_Node parse_block() {
        if (!peek().cmp("{")) {
            return null;
        }
        expect("{");

        Block_Node block = new Block_Node();
        for (int i = 0; has_next() && !peek().cmp("}"); i++) {
            Statement_Node stat = parse_stat();
            if (stat is null) {
                err_logger.Error(peek(), "Expected statement, found: ");
                break;
            }
            block.statements ~= stat;
            if (cast(Semicolon_Stat) stat) {
                expect(";");
            }
        }

        expect("}");
        return block;
    }

    ast.Function_Node parse_func() {
        if (!peek().cmp(keyword.Function)) {
            return null;
        }
        expect(keyword.Function);

        Function_Node func = new Function_Node();
        // TODO: receiver

        func.name = expect(Token_Type.Identifier);

        {
            // func params
            expect("(");
            for (int idx = 0; has_next() && !peek().cmp(")"); idx++) {
                if (idx > 0) {
                    expect(",");
                }
                parse_func_param();
            }
            expect(")");
        }

        func.return_type = parse_type();

        if (peek().cmp("{")) {
            func.func_body = parse_block();
        }
        else {
            expect(";");
        }

        return func;
    }

	ast.Node parse_node() {
        Token tok = peek();

        switch (tok.lexeme) {
        case keyword.Type:
            return parse_named_type();
        case keyword.Function:
            return parse_func();
        case keyword.Directive_Symbol:
            skip_dir();
            break;
        default:
            err_logger.Verbose("unhandled top level node parse_node " ~ to!string(peek()));
            break;
        }
		return null;
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