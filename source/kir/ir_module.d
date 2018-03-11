module kir.ir_mod;

import std.conv;
import std.stdio;
import std.container.array : back;

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

	Function[] functions;

	Value[string] constants;

	Function current_func() {
		return functions.back;
	}

	Function add_function(string name) {
		auto func = new Function();
		// TODO mangle everything properly. but for now
		// this should work
		func.name = "__" ~ module_name ~ "_" ~ sub_module_name ~ "_" ~ name;
		functions ~= func;
		return func;
	}

	void dump() {
		writeln(colour.Bold("# Dumping module '", module_name, "::", sub_module_name, "'"));
		foreach (entry; constants.byKeyValue()) {
			writeln("'" ~ entry.key, " = ", to!string(entry.value));
		}
		// we have consts, do a line break for easier reading
		if (constants.length > 0) {
			writeln;
		}

		foreach (i, func; functions) {
			if (i > 0)
				write('\n');
			func.dump();
		}
		writeln;
	}
}
