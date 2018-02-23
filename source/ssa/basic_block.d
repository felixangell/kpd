module ssa.block;

import std.conv;
import std.stdio;

import ssa.instr;

struct Basic_Block {
	Basic_Block*[] preds;
	Basic_Block*[] succs;

	ulong id;

	Instruction[] instructions;
	Function parent;

	this(Function parent) {
		this.parent = parent;
		this.id = parent.blocks.length;
	}

	void dump() {
		writeln("_bb", to!string(id), ":");
		foreach (instr; instructions) {
			writeln(" ", instr.to_string());
		}
	}

	void add_instr(Instruction instr) {
		instructions ~= instr;
	}
}