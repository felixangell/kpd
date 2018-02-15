import std.string;
import std.uni;
import containers.hashset;
import containers.hashmap;

static HashSet!string EXPRESSION_KEYWORDS;
static HashSet!string BINARY_OPERATORS;
static HashSet!string RELATIONAL_OPERATORS;
static HashSet!string ADD_OPERATORS;
static HashSet!string MUL_OPERATORS;
static HashSet!string UNARY_OPERATORS;
static HashSet!string SYMBOLS;
static HashSet!string KEYWORDS;

static HashMap!(string, uint) OPERATOR_PRECEDENCE;

// ???
template populate_hash_set(T)
{
    void insert(HashSet, T...)(ref HashSet set, T values)
    {
        foreach (val; values)
        {
            set.insert(val);
        }
    }
}

static this()
{
    populate_hash_set!(string).insert(KEYWORDS, "fn", "let", "type", "if", "else",
            "loop", "while", "match", "for", "return", "break", "next", "as", "mut", "default",
            "eval", "len_of", "size_of", "type_of", "struct", "trait", "union", "enum",
            "defer", "false", "true", "bool", "rune", "yield", "self", "clang",);

    OPERATOR_PRECEDENCE["as"] = 6;

    OPERATOR_PRECEDENCE["*"] = 5;
    OPERATOR_PRECEDENCE["/"] = 5;
    OPERATOR_PRECEDENCE["%"] = 5;
    OPERATOR_PRECEDENCE["<<"] = 5;
    OPERATOR_PRECEDENCE[">>"] = 5;
    OPERATOR_PRECEDENCE["&"] = 5;

    OPERATOR_PRECEDENCE["+"] = 4;
    OPERATOR_PRECEDENCE["-"] = 4;
    OPERATOR_PRECEDENCE["|"] = 4;
    OPERATOR_PRECEDENCE["^"] = 4;

    OPERATOR_PRECEDENCE["size_of"] = 3;
    OPERATOR_PRECEDENCE["type_of"] = 3;
    OPERATOR_PRECEDENCE["len_of"] = 3;
    OPERATOR_PRECEDENCE["=="] = 3;
    OPERATOR_PRECEDENCE["!="] = 3;
    OPERATOR_PRECEDENCE["<"] = 3;
    OPERATOR_PRECEDENCE["<="] = 3;
    OPERATOR_PRECEDENCE[">"] = 3;
    OPERATOR_PRECEDENCE[">="] = 3;

    OPERATOR_PRECEDENCE["&&"] = 2;

    OPERATOR_PRECEDENCE["+="] = 1;
    OPERATOR_PRECEDENCE["-="] = 1;
    OPERATOR_PRECEDENCE["/="] = 1;
    OPERATOR_PRECEDENCE["*="] = 1;
    OPERATOR_PRECEDENCE["||"] = 1;
    OPERATOR_PRECEDENCE["="] = 1;
    OPERATOR_PRECEDENCE["..."] = 1;
    OPERATOR_PRECEDENCE[".."] = 1;

    populate_hash_set!(string).insert(EXPRESSION_KEYWORDS, "size_of",
            "type_of", "len_of", "true", "false",);

    populate_hash_set!(string).insert(BINARY_OPERATORS, "||", "&&", "=", "as",
            "::", "..", "...", "+=", "-=", "/=", "*=",);

    populate_hash_set!(string).insert(RELATIONAL_OPERATORS, "==", "!=", "<", ">", "<=", ">=");

    populate_hash_set!(string).insert(ADD_OPERATORS, "+", "-", "|", "^");

    populate_hash_set!(string).insert(MUL_OPERATORS, "*", "/", "%", "<<", ">>", "&");

    populate_hash_set!(string).insert(UNARY_OPERATORS, "+", "-", "!", "^", "@", "&");

    populate_hash_set!(string).insert(SYMBOLS, "::", "->", "@", "=>", "<-",
            "!=", "==", "<=", ">=", "<<", ">>", "..", "&&", "||", "as", "+=",
            "-=", "/=", "*=", "%", "=", "*", ":", "^", "+", "-", "!", "#",
            "/", ",", ";", ".", "[", "]", "{", "}", "(", ")", "<", ">", "&",);
}

static int get_op_prec(string s)
{
    if (s in OPERATOR_PRECEDENCE)
    {
        return OPERATOR_PRECEDENCE[s];
    }
    // TODO:?
    return -1;
}

static bool is_binary_op(string s)
{
    return BINARY_OPERATORS.contains(s) || is_rel_op(s) || is_add_op(s) || is_mul_op(s);
}

static bool is_rel_op(string s)
{
    return RELATIONAL_OPERATORS.contains(s);
}

static bool is_add_op(string s)
{
    return ADD_OPERATORS.contains(s);
}

static bool is_mul_op(string s)
{
    return MUL_OPERATORS.contains(s);
}

static bool is_unary_op(string s)
{
    return UNARY_OPERATORS.contains(s);
}

auto is_identifier = (dchar c) => isAlpha(c) || isNumber(c) || c == '_';
auto is_decimal = (dchar c) => (c >= '0' && c <= '9') || c == '_';
auto is_hexadecimal = (dchar c) => isNumber(c) || (c >= 'a' && c <= 'f')
    || (c >= 'A' && c <= 'F') || c == '_';
auto is_octal = (dchar c) => (c >= '0' && c <= '7') || c == '_';
auto is_binary = (dchar c) => c == '0' || c == '1' || c == '_';

static bool str_is_identifier(string s)
{
    if (s.startsWith("_") || isNumber(s[0]))
    {
        return false;
    }

    foreach (dchar character; s)
    {
        if (!is_identifier(character))
        {
            return false;
        }
    }
    return true;
}
