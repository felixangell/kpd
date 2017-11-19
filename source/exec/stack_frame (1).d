module exec.stack_frame;

import std.bitmanip;

import exec.exec_engine;
import exec.virtual_thread;

class Stack_Frame {
	Virtual_Thread parent_thread;
	Stack_Frame parent;

	byte[LOCALS_SIZE] locals;
	uint local_index = 0;

	this(Virtual_Thread parent_thread) {
		this.parent_thread = parent_thread;
	}

	void push(T)(T value) {
		locals.append!T(value, Endian.bigEndian);
	}

	T pop(T)() {
		return locals.peek!(T, Endian.bigEndian);
	}
}