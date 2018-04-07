module gen.kurby.output;

import std.stdio;
import std.conv;
import std.bitmanip;

import gen.backend;
import gen.kurby.opcode;

import logger;
import kir.instr;

class Kurby_Byte_Code : Generated_Output {
    uint program_index = 0;
	ubyte[] program;
    uint[string] func_addr_reg;

    uint emit(Encoded_Instruction instr) {
		writeln(instr);
				
		auto idx = program_index;
		program_index += instr.data.length;
		program ~= instr.data;
		return idx;
	}

	OP get_op(uint index) {
		auto data = program[index..$];
		return cast(OP)(data.peek!(ushort, Endian.bigEndian));
	}

	void rewrite(uint index, Encoded_Instruction instr) {
		foreach (idx, val; instr.data) {
			program[index + idx] = val;
		}
	}

}