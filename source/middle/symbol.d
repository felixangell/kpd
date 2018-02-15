module sema.symbol;

import std.conv;

import err_logger;
import ast;
import sema.infer : Type_Environment;
import sema.type;
import krug_module : Token;

class Symbol_Value
{
    ast.Node reference;
    Token tok;
    string name;
    Type type;

    this(ast.Node reference, Token tok)
    {
        this(reference, tok.lexeme);
        this.tok = tok;
    }

    this(ast.Node reference, string name)
    {
        this.reference = reference;
        this.name = name;
    }

    this()
    {
        // debug only
        this.name = "__anonymous_sym_table";
    }

    override string toString() const
    {
        if (reference is null)
        {
            return name;
        }
        return name ~ " val " ~ to!string(typeid(reference));
    }
}

class Symbol_Table : Symbol_Value
{
    Symbol_Table parent, child;
    Symbol_Value[string] symbols;

    uint id;
    Type_Environment env;

    this(ast.Node reference, Token tok)
    {
        this(reference, tok.lexeme);
    }

    this(ast.Node reference, string name)
    {
        super(reference, name);
    }

    this()
    {
        super();
        env = new Type_Environment;
    }

    // registers the given symbol, if the
    // symbol already exists it will be
    // returned from the symbol table in the scope.
    Symbol_Value register_sym(string name, Symbol_Value s)
    {
        err_logger.Verbose("Registering symbol " ~ name ~ " // " ~ to!string(s));
        if (name in symbols)
        {
            return symbols[name];
        }
        symbols[name] = s;
        return null;
    }

    Symbol_Value register_sym(Symbol_Value s)
    {
        return register_sym(s.name, s);
    }

    override string toString() const
    {
        if (reference is null)
        {
            return name ~ " (table) ";
        }
        return name ~ " (table) " ~ to!string(typeid(reference));
    }
}

// is this even necessary?
class Symbol : Symbol_Value
{
    // bog standard entry really.
    this(ast.Node reference, Token tok)
    {
        super(reference, tok);
    }

    this(ast.Node reference, string name)
    {
        super(reference, name);
    }

    override string toString() const
    {
        if (reference is null)
        {
            return name;
        }
        return name ~ " -> " ~ to!string(typeid(reference));
    }
}
