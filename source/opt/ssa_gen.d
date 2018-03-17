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

import opt.pass;

import logger;

// for now this pass simply
// evaluates simple expressions in
// binary expressions _only_
class SSA_Builder : Optimisation_Pass {
	
	void ssa_func(Function f) {
		auto entry_bb_name = f.blocks[0].name();
		
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