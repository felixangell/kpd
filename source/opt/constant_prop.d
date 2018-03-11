module opt.constant_prop;

import std.stdio;
import std.conv;

import kir.ir_mod;
import kir.instr;

import opt.pass;

// for now this pass simply
// evaluates simple expressions in
// binary expressions _only_
class Constant_Prop : Optimisation_Pass {
	void process(Kir_Module mod) {
	}
}