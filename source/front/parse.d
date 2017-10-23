module parse.parser;

import std.stdio;
import std.conv;

import grammar;
import krug_module;
import compilation_phase;
import ast;

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

    Token expect(string str) {
        if (!peek().cmp(str)) {
            err_logger.Error("Expected '" ~ str ~ "', found: '" ~ to!string(peek()));
            assert(0);
        }
        return consume();
    }

    Token expect(Token_Type type) {
        if (!peek().cmp(type)) {
            err_logger.Error("Expected '" ~ to!string(type) ~ "', got " ~ to!string(peek()));
            assert(0);
        }
        return consume();
    }

    void skip_dir() {
        expect("#");
        auto name = expect(Token_Type.Identifier);
        switch (name.lexeme) {
        case "load":
            expect(Token_Type.Identifier);
            if (peek().cmp("::")) {
                consume();
                if (peek().cmp("{")) {
                    consume();
                    int idx = 0;
                    while (!peek().cmp("}")) {
                        if (idx++ > 0) {
                            expect(",");
                        }
                        consume();
                    }
                    expect("}");
                } else {
                    expect(Token_Type.Identifier);
                }
            }
            break;
        default: break;
        }
    }

    ast.Type_Node parse_type() {
        Token tok = peek();
        if (tok.lexeme in PRIMITIVE_TYPES) {
            return new Primitive_Type_Node(consume());
        }
        return null;
    }

    ast.Named_Type parse_named_type() {
        if (!peek().cmp("type")) {
            return null;
        }
        expect("type");

        auto name = expect(Token_Type.Identifier);
        auto type = parse_type();
        return new Named_Type(name, type);
    }

    ast.Function_Parameter parse_func_param() {
        bool mutable = false;
        if (peek().cmp("mut")) {
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
        case "size_of":
        case "len_of":
        case "type_of":
            // TODO:
            break;
        default: break;
        }

        // boolean literal
        switch (curr.lexeme) {
        case "true": case "false":
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

        // eval expr

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
        if (!peek().cmp("let")) {
            return null;
        }
        consume();

        bool mutable = false;
        if (peek().cmp("mut")) {
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
        if (type is null && !peek().cmp("=")) {
            // error: expected type in variable binding!
        }

        auto var = new Variable_Statement_Node(name, type);
        var.mutable = mutable;

        if (peek().cmp("=")) {
            consume();

            var.value = parse_expr();
            if (var.value is null) {
                // error: expected value after assignment operator.
            }
        }

        return var;
    }

    ast.Statement_Node parse_stat() {
        Token tok = peek();
        switch (tok.lexeme) {
        case "let":
            return parse_let();
        default: break;
        }

        assert("unhandled statement " ~ to!string(peek()));
        return null;
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
                err_logger.Error("Expected statement, found " ~ to!string(peek()));
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
        if (!peek().cmp("func")) {
            return null;
        }
        expect("func");

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
        } else {
            expect(";");
        }

        return func;
    }

	ast.Node parse_node() {
        Token tok = peek();
        switch (tok.lexeme) {
        case "type":
            return parse_named_type();
        case "func":
            return parse_func();
        case "#":
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