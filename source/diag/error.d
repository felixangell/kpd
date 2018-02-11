module diag.error;

import std.stdio;
import core.vararg;

import diag.engine;

struct Compiler_Error {
	string detail;
	string[] errors;
}

Compiler_Error make_err(string detail, string[] errors ...) {
	Compiler_Error compiler_err;
	compiler_err.detail = detail;
	compiler_err.errors = errors;

	return compiler_err;
}

// TODO arae there raw strings or something where we can not
// do the runtime appendy stuff?

enum Error_Set : Compiler_Error {
	SYMBOL_CONFLICT = make_err(
		  "Two symbols in the same scope have been defined\n"
		~ "with conflicting names. Symbols must have distinct\n" 
		~ "names, otherwise there is an ambiguity when compiling\n" 
		~ "the program. This is beacuse the compiler doesn't know\n" 
		~ "what symbol you are referring to:\n\n" 
		~ "   let x = 3;\n" 
		~ "   let x = 5;\n"
		~ "   let z = x + x; // <- which x are we referring to here?\n"
		~ "To resolveTo this error, rename the conflicting symbols to have\n" 
		~ "different names:\n\n" 
		~ "   let x = 3;\n" 
		~ "   let b = 4;\n" 
		~ "   let z = x + b;\n\n"
		, "Symbol '%s' defined here:", "Conflicts with symbol '%s' defined here:"), 
	
	UNRESOLVED_SYMBOL = make_err(
		  "A symbol (variable, function, module, etc.) could not be found\n"
		~ "there are a few possible causes for this error:\n\n" 		
		~ "## The symbol has no definition in the program:\n" 		
		~ "In this case, there was no definition for some symbol S, i.e.\n" 		
		~ "you are referring to a symbol that does not exist:\n\n" 		
		~ "    let foo = 3;\n" 		
		~ "    let bar = foo 		
		~ baz; // where is baz?\n\n" 		
		~ "To fix this error, simply define the unresolved symbol:\n\n" 		
		~ "    let baz = 6;         // now we know where baz is!\n" 		
		~ "    let foo = 3;\n" 		
		~ "    let bar = foo 		
		~ baz;\n\n" 		
		~ "A more complex example would be we are invoking a method that\n" 		
		~ "does not exist:\n\n" 		
		~ "    type Person struct {\n" 		
		~ "        name string,\n" 		
		~ "        age uint,\n" 		
		~ "    };\n\n" 		
		~ "    let felix Person = Person{name: \"Felix\", age: 18};\n" 		
		~ "    felix.greet();  // greet has not been \n" 		
		~ "                    // defined for the Person structure\n\n" 		
		~ "The fix in this case, again, would be to define the symbol:\n\n" 		
		~ "    type Person struct {\n" 		
		~ "        name string,\n" 		
		~ "        age uint,\n" 		
		~ "    };\n\n" 		
		~ "    fn (p *Person) greet() {\n" 		
		~ "        // do things here.\n" 		
		~ "    } \n\n" 		
		~ "    let felix Person = Person{name: \"Felix\", age: 18};\n" 		
		~ "    felix.greet();  // greet has not been \n" 		
		~ "                    // defined for the Person structure\n\n" 		
		~ "## The symbol has not been imported into the current module:\n" 		
		~ "This means that the symbol is defined somewhere in another module\n" 		
		~ "but has not been loaded:\n\n" 		
		~ "    let a = 5;\n" 		
		~ "    let b = 10;\n" 		
		~ "    let foo = math.Min(a, b);\n\n" 		
		~ "In this example, we are invoking the `Min` method from the math\n" 		
		~ "module, but the math module has not been loaded. Thus causing an\n" 		
		~ "unresolved symbol error.\n" 		
		~ "The fix in this case, would be to load the module:\n\n" 		
		~ "    #load math\n\n" 		
		~ "    let a = 5;\n" 		
		~ "    let b = 10;\n" 		
		~ "    let foo = math.Min(a, b);\n\n" 		
		~ "## The symbol has been mis-spelled:\n" 		
		~ "This case is as simple as a spelling error!\n\n" 		
		~ "    let bar = 6;\n" 		
		~ "    let foo = barr; // error!\n\n" 		
		~ "The solution to this case is to fix the spelling error:\n\n" 		
		~ "    let bar = 6;\n" 		
		~ "    let foo = bar;\n"
		, "Unresolved symbol '%s':"), 

	OUT_OF_BOUNDS_INDEX = make_err(
		  "This occurs when attempting to access a symbol by an out of bounds index.\n" 		
		~ "The error can be thrown with an array or a tuple. For example, given\n" 		
		~ "the tuple (int, int, rune), there are three values in the tuple.\n" 		
		~ "If you attempted to access at the index of 5, this will throw\n" 		
		~ "an out of bounds error, as there is no value at the index 5:\n\n" 		
		~ "    int, int, rune, junk, junk, junk, junk, ..., junk, ...\n" 		
		~ "     0,   1,   2,    3,    4,    5,     6,  ...,\n" 		
		~ "\n" 		
		~ "    let bar = {5, 10, 'a', \"hello!\"};\n" 		
		~ "    let foo = bar.2; // OK!\n" 		
		~ "    let foobar = bar.99; // BAD!\n" 		
		~ "\n\n" 		
		~ "To resolve this issue, simply make sure you aren't accessing at\n" 		
		~ "an invalid index for an array or tuple."
		, "Attempted out of bounds index on symbol '%s':"),

	TYPE_MISMATCH = make_err(
		"This occurs when two types mismatch.\n", 
		"Type '%s':", 
		"Mismatch with type '%s':"),
}