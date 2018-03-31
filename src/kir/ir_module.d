module kir.ir_mod;

import std.conv;
import std.stdio;
import std.container.array;

import colour;
import kir.instr;

class Kir_Module {
	// the name of the parent module
	string module_name;

	// the name of the sub_module
	// which is what THIS class representms
	string sub_module_name;

	this(string module_name, string sub_module_name) {
		this.module_name = module_name;
		this.sub_module_name = sub_module_name;
	}

	Kir_Module[string] dependencies;

	Function[string] functions;
	Value[string] constants;

	// most recently added func
	Function recent_func;

	Function current_func() {
		return recent_func;
	}

	Function get_function(string name) {
		string mangle = "__" ~ module_name ~ "_" ~ sub_module_name ~ "_" ~ name;
		if (mangle in functions) {
			return functions[mangle];
		}
		return null;
	}

	Function add_function(string name) {
		auto func = new Function();
		// TODO mangle everything properly. but for now
		// this should work
		func.name = "__" ~ module_name ~ "_" ~ sub_module_name ~ "_" ~ name;
		functions[func.name] = func;
		recent_func = func;
		return func;
	}

	void dump() {
		writeln(colour.Bold("Dumping module '", module_name, "::", sub_module_name, "'"));
		foreach (entry; constants.byKeyValue()) {
			writeln("'" ~ entry.key, " = ", to!string(entry.value));
		}
		// we have consts, do a line break for easier reading
		if (constants.length > 0) {
			writeln;
		}

		int i = 0;
		foreach (name, func; functions) {
			if (i++ > 0)
				write('\n');
			func.dump();
		}
		writeln;
	}
}
