module exec.instruction;

import std.bitmanip;

static enum OP {
	PSH, PSHI, PSHL,
}

struct Instruction {
	ushort id;
	ubyte[] data;

	this(ubyte[] data) {
		// the id of the instruction is copied from
		// the first two bytes of the data we pass thru.
		this.id = data.peek!(ushort, Endian.bigEndian);
		this.data = data;
	}

	void put(T)(T val) {
		data.append!(T)(val);
	}
}

static Instruction encode(Op, T...)(Op id, T values) {
	ubyte[] data;
	data.append!(ushort, to!ushort(id));
	foreach (val; values) {
		data.append!(T, val);
	}
	return Instruction(data);
}