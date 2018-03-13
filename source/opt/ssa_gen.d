module opt.ssa_gen;

import std.stdio;
import std.conv;

import kir.ir_mod;
import kir.instr;

import opt.pass;

struct Definitions {
	Value[string] values;
}

Basic_Block[string] sealed;
Definitions[string] bb_defs;
Definitions current_def;

void write_var(Basic_Block block, string name, Value val) {
	if (block.name() !in bb_defs) {
		bb_defs[block.name()] = Definitions();
	}
	bb_defs[block.name()].values[name] = val;
}

Value read_val_recursive(Basic_Block block, string name) {
	assert(0, "unimplemented!");
}

Value read_val(Basic_Block block, string name) {
	if (block.name() in bb_defs) {
		auto defs = bb_defs[block.name()];
		if (name in defs.values) {
			return defs.values[name];
		}
	}
	return block.read_val_recursive(name);
}

// for now this pass simply
// evaluates simple expressions in
// binary expressions _only_
class SSA_Builder : Optimisation_Pass {
	void opt_basic_block(Basic_Block bb) {
		foreach (instr; bb.instructions) {
					
		}
	}

	void ssa_func(Function f) {
		foreach (bb; f.blocks) {
			opt_basic_block(bb);
		}
	}

	void process(Kir_Module mod) {
		foreach (func; mod.functions) {
			ssa_func(func);
		}
	}
}