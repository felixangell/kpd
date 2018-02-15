// scope is a keyword so we'll dump it in
// a module called range for now
module sema.range;

import std.conv;

import ast;
import err_logger;
import krug_module : Token;
import sema.infer : Type_Environment;
import sema.type;
import sema.symbol;

class Scope
{
    uint id;
    Scope outer;
    Type_Environment env;

    this()
    {
        this(null);
    }

    this(Scope outer)
    {
        this.outer = outer;
        this.id = outer is null ? 0 : (outer.id + 1);
        env = outer is null ? new Type_Environment() : new Type_Environment(outer.env);
    }
}
