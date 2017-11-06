# krug
Krug is a compiled programming language

## under the hood
this is a brief run-down of the architecture 
of the compiler thus far. things are subject
to change, so take this with a grain of salt as
i probably wont keep this section as up to date
as it should be.

for now to summarize in bullet points:

- load the main module (main.krug)
- lex the main module
- parse the tokens for DIRECTIVES - specifically load directives to build a dependency graph
- load all modules and lex/LOAD DIRECTIVE parse them
- build a dependency graph
- run tarjans algorithm to detect cycles in the dependency graph
- flatten the graph and sort it by least amount of 
dependencies this is so that it's easier when we run symbol resolution because
hopefully all of the symbols will have been defined rather than jumping around dependencies
hunting for symbols.
- run the parser over the flattened modules to parse
into an Abstract Syntax Tree
- run semantic analysis on the AST
    * declaration pass - go through all of the declarations
    and register them as symbols, scope emulation, etc.
    * 

## warning
this is in no way a production-quality compiler!
the code-base is written in a very c-like/c++ 
naive way, in other words, i don't know how to 
write idiomatic D code