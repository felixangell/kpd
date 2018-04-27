module kir.ir_mod;

import std.conv;
import std.stdio;
import std.container.array;

import sema.type;
import colour;
import kir.instr;
import kir.block_ctx;

/*
	todo some cleanup here is in order
	an ir_module should have sub_module_name
	as just name ie. each krug sub module
	is an ir_module

	then we need an enclsoing thing i.e.
	one Krug module is many IR_Modules

	and then dependencies can either be a
	Module (i.e. a bundle of IR_Modules)
	or just an IR_Module!
*/

class IR_Module {
	// the name of the sub_module
	string mod_name;

	Block_Context[string] ctx;

	this(string mod_name) {
		this.mod_name = mod_name;

		// this causes a smallAlloc seg fault for some reason?
		// this.c_mod = new IR_Module("c", "main");
	}

	IR_Module[string] dependencies;
	Function[string] c_funcs;
	Function[string] functions;
	Value[string] constants;

	// most recently added func
	Function recent_func;

	Function current_func() {
		return recent_func;
	}

	void add_dependency(IR_Module dep) {
		writeln("ir_mod ", mod_name, " deps on ", dep.mod_name);
		dependencies[dep.mod_name] = dep;
	}

	Function get_function(string name) {
		if ((name in functions) !is null) {
			return functions[name];
		}
		if ((name in c_funcs) !is null) {
			return c_funcs[name];
		}
		return null;
	}

	Function add_function(string name, Type type = new Void()) {
		auto func = new Function(name, type, this);
		functions[func.name] = func;
		recent_func = func;
		return func;
	}

	void dump() {
		writeln(colour.Bold("Dumping module '", mod_name, "'"));
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
