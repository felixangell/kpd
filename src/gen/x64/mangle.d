module gen.x64.mangler;

import std.conv : to;

import kir.instr;

// NOTE
// M(x) means mangled form of x
// for example
// M(func) => mangled form of func
// M(word) => mangled form of word, i.e. 
// 			  M(foo) => 3foo

// length of word followed by the word
// for example
// 
// 11hello_world
// 3foo
// 5felix
string mangle(string word) {
	return to!string(word.length) ~ word;
}

string mangle_join(T...)(T values...) {
	string res;
	foreach (i, v; values) {
		if (i > 0) res ~= "_";
		res ~= mangle(v);
	}
	return res;
}

// M(module) + M(submodule) + M(func_name) + M(func_args...)
string mangle(Function f) {
	// even though this will probably have the
	// no_mangle attribute, we still mangle it
	if (f.has_attribute("c_func")) {
		// i think this is right?
		return "_" ~ f.name;
	}

	if (f.has_attribute("no_mangle")) {
		return f.name;
	}
	
	return "__" ~ mangle_join!(string, string, string)(
		f.parent_mod.module_name,
		f.parent_mod.sub_module_name,
		f.name,
	);
}

string mangle(Basic_Block f) {
	return mangle_join!(Function, string)(
		f.parent,
		f.name(),
	);
}

unittest {

}