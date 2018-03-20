module opt.ssa_gen;

import std.typecons;
import std.stdio;
import std.conv;
import std.algorithm : remove, sort;
import std.range.primitives;

import kt;
import kir.ir_mod;
import kir.instr;
import kir.cfg;

import opt.dom;
import opt.pass;

import logger;

string bb_to_string(BB_Node b) {
	return b.value.name();
}

// for now this pass simply
// evaluates simple expressions in
// binary expressions _only_
class SSA_Builder : Optimisation_Pass {

	void ssa_func(Function f) {
		auto entry_bb_name = f.blocks[0].name();
		
		auto dom_tree = new Dominator_Tree().build(f);
		foreach (k, doms; dom_tree) {
			writeln("node ", k.bb_to_string(), " dominates:");
			foreach (d; doms) {
				writeln("- ", d.bb_to_string());
			}
			writeln;
		}
	}

	void process(Kir_Module mod) {
		foreach (func; mod.functions) {
			ssa_func(func);
		}
	}

	override string toString() {
		return "Static Single Assignment";
	}
}