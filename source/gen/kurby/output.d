module gen.kurby.output;

import std.stdio;
import std.conv;

import gen.backend;
import gen.kurby.opcode;

import logger;
import kt;
import kir.instr;

class Kurby_Byte_Code : Generated_Output {
    uint program_index = 0;
	ubyte[] program;
    uint[string] func_addr_reg;

    uint emit(Encoded_Instruction instr) {
        logger.Verbose("Emitting ", to!string(instr));

		auto idx = program_index;
		program_index += instr.data.length;
		program ~= instr.data;
		return idx;
	}

	void rewrite(uint index, Encoded_Instruction instr) {
		foreach (idx, val; instr.data) {
			program[index + idx] = val;
		}
	}

}