module ssa.ir_module;

import std.container.array : back;

import ssa.instr;

class IR_Module {
	Function[] functions;

	Function current_func() {
		return functions.back;
	}

	Function add_function(string name) {
		auto func = new Function();
		func.name = name;
		functions ~= func;
		return func;
	}

	void dump() {
		foreach (func; functions) {
			func.dump();
		}
	}
}