module compiler_error;

import core.vararg;
import std.stdio;
import std.conv;
import std.typetuple;

import diag.engine;

/*
    COMPILER ERROR GUIDELINES
    -------------------------

    to create an error, you must use the mixin/template make_err

        mixin(make_err!("ERROR_NAME", "XXXXu", `Shown when ./krug explain EXXXX.`, 
            "Compiler message here before code sample '%s':",
            "Compiler message here before another code sample '%s':"));

        Note the %s is the TOKEN that we pass to the compiler error.
        The code sample is taken from the token. So the first message
        will show the code sample for the first %s, and the second
        message will show the code sample for second %s, and so on.

    errors are invoked in the code with ERROR_NAME, for example

        Diagnostic_Engine.throw_error(SYMBOL_CONFLICT, param.get_tok_info(), conflicting_param.get_tok_info());

    The XXXXu is the identifier of the error. This should not be a duplicate of any existing
    error codes. Manually increment the previous error id when creating an error.

    COMPILE ERROR MESSAGE GUIDELINES
    --------------------------------

    The compiler error _must_ clearly explain the error.
    The compiler error _must_ have a *code* example of what causes the error.
    The compiler error _must_ have a way to resolve the error (with code sample).
    The compiler code samples _must_ be runnable on their own!

    An error message can be caused by a variety of reasons. Bonus points for providing
    _multiple_ causes of an error. However, prefer the most common cause of the error
    first.

*/

struct Compiler_Error {
	ushort id;
	string detail;
	string[] errors;
}

immutable bool DUMP_ERROR_MIXINS = false;

Compiler_Error[ushort] ERROR_REGISTER;

enum is_string(string s) = true;

string emit(strings...)() if (allSatisfy!(is_string, strings)) {
	string errors;
	foreach (idx, f; strings) {
		if (idx > 0) {
			errors ~= ',';
		}
		errors ~= '"' ~ f ~ '"';
	}
	return errors;
}

template make_err(string name, string id, string detail, strings...) {
	const char[] make_err = "enum " ~ name ~ " = Compiler_Error(" ~ id ~ ",`" ~
		detail ~ "`,[" ~ emit!(strings) ~
		"]);" // this is weird, we generate a static block for each error
		 ~ "static this() { ERROR_REGISTER[" ~ id ~ "] = " ~ name ~ "; }";

	static if (DUMP_ERROR_MIXINS) {
		pragma(msg, "result ", make_err);
	}
}

mixin(make_err!("SYMBOL_CONFLICT", "0000u",
		`Two symbols in the same scope have been defined
with conflicting names. Symbols must have distinct
names, otherwise there is an ambiguity when compiling
the program. This is beacuse the compiler doesn't know 
what symbol you are referring to:

   let x = 3;
   let x = 5;
   let z = x + x; // <- which x are we referring to here?

To resolve this error, rename the conflicting symbols to have
different names:

   let x = 3; 
   let b = 4; 
   let z = x + b;
`,
		"Symbol '%s' defined here", "Conflicts with symbol '%s' defined here"));

mixin(make_err!("DEPENDENCY_CYCLE", "0004u", "TODO", "TODO!"));

mixin(make_err!("UNRESOLVED_SYMBOL", "0001u",
		`A symbol (variable, function, module, etc.) could not be found
there are a few possible causes for this error:

## The symbol has no definition in the program: 		
In this case, there was no definition for some symbol S, i.e. 		
you are referring to a symbol that does not exist: 		

    let foo = 3; 		
    let bar = foo 		
	baz = foo; 				// where is baz? 		

To fix this error, simply define the unresolved symbol: 		
    let baz = 6;         	// now we know where baz is! 		
    let foo = 3; 		
    let bar = foo 		
    baz = foo;

A more complex example would be we are invoking a method that 		
does not exist: 	

    type Person struct { 		
        name string, 		
        age uint, 		
    }; 		
    let felix Person = Person{name: "Felix", age: 18}; 		
    felix.greet();  		// greet has not been  		
                    		// defined for the Person structure

The fix in this case, again, would be to define the symbol: 		

    type Person struct { 		
        name string, 		
        age uint, 		
    }; 		
    fn (p *Person) greet() { 		
        // do things here. 		
    }  		
    let felix Person = Person{name: "Felix", age: 18}; 		
    felix.greet();  		// greet has not been  		
                    		// defined for the Person structure 		

## The symbol has not been imported into the current module: 		
This means that the symbol is defined somewhere in another module 		
but has not been loaded: 		
    
    let a = 5; 		
    let b = 10; 		
    let foo = math.Min(a, b);

In this example, we are invoking the 'Min' method from the math 		
module, but the math module has not been loaded. Thus causing an 		
unresolved symbol error. 		

The fix in this case, would be to load the module: 

    #load math 		
    let a = 5; 		
    let b = 10; 		
    let foo = math.Min(a, b);

## The symbol has been mis-spelled: 		
This case is as simple as a spelling error! 		

    let bar = 6; 		
    let foo = barr; // error!

The solution to this case is to fix the spelling error: 		

    let bar = 6; 		
    let foo = bar;
`,
		"Unresolved symbol '%s'"));

mixin(make_err!("OUT_OF_BOUNDS_INDEX", "0002u", `This occurs when attempting to access a symbol by an out of bounds index. 		

The error can be thrown with an array or a tuple. For example, given 		
the tuple (int, int, rune), there are three values in the tuple. 		

If you attempted to access at the index of 5, this will throw 		
an out of bounds error, as there is no value at the index 5: 		

    int, int, rune, junk, junk, junk, junk, ..., junk, ... 		
     0,   1,   2,    3,    4,    5,     6,  ..., 		
 		
    let bar = {5, 10, 'a', "hello!"}; 		
    let foo = bar.2; // OK! 		
    let foobar = bar.99; // BAD! 		
 		
To resolve this issue, simply make sure you aren't accessing at 		
an invalid index for an array or tuple."
`, "Attempted out of bounds index on symbol '%s':"));

mixin(make_err!("TYPE_MISMATCH", "0003u",
	`This occurs when two types mismatch.`,
	"Type '%s'", "Mismatch with type '%s'"));

mixin(make_err!("NO_TYPE_ANNOTATION", "0004u",
    `TODO.`,
    "No type annotation for binding '%s'"));

mixin(make_err!("COMPILE_TIME_EVAL", "0005u",
    `TODO.`,
    "Failed to evaluate expression at compile-time '%s'"));

mixin(make_err!("IMMUTABLE_ASSIGN", "0006u", `This occurs when attempting to re-assign an immutable variable.

For example:
    
    func main() {
        let x = 3;
        x = 4; // error, re-assignment of immutable variable
    }

To resolve this issue, make the variable mutable with the 'mut' keyword:

    func main() {
        mut x = 3;
        x = 4; // ok!
    }

`, "Cannot assign to immutable variable '%s':"));