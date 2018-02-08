module exec.byte_stack;

import std.bitmanip;

import exec.exec_engine;

struct Byte_Stack {

	size_t stack_ptr;
	ubyte[STACK_SIZE] data;

	void push(T)(T val) {
		write!(T)(data[], val, stack_ptr);
		stack_ptr += T.sizeof;
	}

	bool is_empty() {
		return stack_ptr < 0;
	}

	T pop(T)() {
		auto value = peek!T(data[stack_ptr .. $]);
		stack_ptr -= T.sizeof;
		return value;
	}

}