module parse.parser;

import std.stdio;
import std.conv;

import err_logger;
import krug_module;
import ast;
import ds;

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

struct Parser {
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
        expect("type");
        auto name = expect(Token_Type.Identifier);
        auto type = parse_type();
        return new Named_Type(name, type);
    }

	ast.Node parse_node() {
	    if (peek().cmp("#")) {
	        skip_dir();
	    }
        Token tok = peek();
        switch (tok.lexeme) {
        case "type":
            return parse_named_type();
        default:
            writeln(peek());
            break;
        }
		return null;
	}

	Token peek(uint offs = 0) {
	    if (pos + offs >= toks.length) {
	        err_logger.Verbose("warning, reached EOF when parsing " ~ to!string(peek(-1)));
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
}