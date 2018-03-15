module opt.ssa_gen;

import std.stdio;
import std.conv;
import std.algorithm : remove;

import kt;
import kir.ir_mod;
import kir.instr;

import opt.pass;

import logger;

struct Definitions {
	Value[string] values;
	Phi[string] incomplete_phis;
}

Basic_Block[string] sealed;

Definitions[string] bb_defs;
Definitions current_def;

void write_var(Basic_Block block, string name, Value val) {
	if (block.name() !in bb_defs) {
		bb_defs[block.name()] = Definitions();
	}
	writeln("- ssa: Storing ", to!string(val), " as ", name, " in bb ", block.name());
	auto defs = bb_defs[block.name()];
	defs.values[name] = val;
}

void write_phi(Basic_Block block, string name, Phi phi) {
	if (block.name() !in bb_defs) {
		bb_defs[block.name()] = Definitions();
	}

	writeln("- ssa: Incomplete phi ", to!string(phi), " as ", name, " in bb ", block.name());
	bb_defs[block.name()].incomplete_phis[name] = phi;	
}

Value remove_trivial_phi(Phi p) {
	Value same = null;
	foreach (e; p.edges) {
		if (e is same || e == p) {
			continue;
		}
		if (same !is null) {
			return p;
		}
		same = p;
	}

	if (same is null) {
		same = new Undef();
	}

	// this is wrong
	foreach (i, u; p.users) {
		if (u == p) {
			remove(p.users, i);	
		}

		if (auto phi = cast(Phi)u) {
			remove_trivial_phi(phi);
		}
	}

	return same;
}

Value calculate_phi_operands(Phi phi, Basic_Block bb, string name) {
	foreach (p; bb.preds) {
		phi.add_edge(read_var(p, name));
	}
	return remove_trivial_phi(phi);
}

Value read_val_recursive(Basic_Block block, string name) {
	Value val = null;
	if (block.name() !in sealed) {
		val = new Phi();
		block.write_phi(name, cast(Phi) val);
	}
	else if (block.preds.length == 1) {
		val = read_var(block.preds[0], name);
	}
	else {
		val = new Phi();
		val = calculate_phi_operands(cast(Phi) val, block, name);
	}
	block.write_var(name, val);
	return val;
}

Value read_var(Basic_Block block, string name) {
	if (block.name() in bb_defs) {
		auto defs = bb_defs[block.name()];
		if (name in defs.values) {
			writeln("- ssa: Read value ", name, " from bb ", block.name());
			return defs.values[name];
		}
	}
	return block.read_val_recursive(name);
}

void read_value(Basic_Block bb, Value val) {
	if (auto iden = cast(Identifier) val) {
		bb.read_var(iden.name);
	}
	else if (auto bin = cast(BinaryOp) val) {
		read_value(bb, bin.a);
		read_value(bb, bin.b);
	}
	else {
		if (!(cast(Constant) val)) {
			logger.Fatal("unhandled value read! ", to!string(val));			
		}
	}
}

// for now this pass simply
// evaluates simple expressions in
// binary expressions _only_
class SSA_Builder : Optimisation_Pass {
	void opt_instr(Basic_Block bb, Instruction instr) {
		if (auto alloc = cast(Alloc) instr) {

		}
		else if (auto store = cast(Store) instr) {
			if (auto alloc = cast(Alloc) store.address) {
				bb.write_var(alloc.name, store.val);
			}
			bb.read_value(store.val);
		}
		else {
			logger.Fatal("- ssa: unhandled instruction ", to!string(instr));
		}
	}

	void opt_basic_block(Basic_Block bb) {
		foreach (instr; bb.instructions) {
			opt_instr(bb, instr);
		}

		if (bb.name() !in bb_defs) {
			logger.Fatal("Basic block ", bb.name(), " has not been SSA checked!");
			return;
		}

		// seal the block.
		auto defs = bb_defs[bb.name()];
		foreach (name, phi; defs.incomplete_phis) {
			calculate_phi_operands(phi, bb, name);
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