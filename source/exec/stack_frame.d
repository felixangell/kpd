module exec.stack_frame;

import std.bitmanip;

import exec.exec_engine;
import exec.virtual_thread;

class Stack_Frame {
	Virtual_Thread parent_thread;
	Stack_Frame parent;

	ubyte[LOCALS_SIZE] locals;
	uint local_index = 0;
	uint return_addr = -1;

	this(Virtual_Thread parent_thread) {
		this.parent_thread = parent_thread;
	}

	void push(T)(T val) {
		write!(T)(val, parent_thread.stack, &parent_thread.stack_ptr);
	}

	T pop(T)() {
		return peek!T(parent_thread.stack[parent_thread.stack_ptr .. $]);
	}

	uint store_local(T)(T value) {
		locals[local_index].append!(T)(value, Endian.bigEndian);
		local_index += value.size_of;
		return local_index;
	}

	T get_local(T)(uint addr) {
		return locals[addr].peek!(T, Endian.bigEndian);
	}
}