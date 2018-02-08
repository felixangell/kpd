module exec.virtual_thread;

import exec.exec_engine;
import exec.byte_stack;
import exec.stack_frame;

struct Virtual_Thread {
	Byte_Stack stack;

	ubyte[DATA_SEGMENT_SIZE] globals;

	Stack_Frame current_frame;
	uint program_counter = 0;

	// do we segment this ?
	void store_global(T)(T value, uint addr) {
		globals[addr].append!T(value, Endian.bigEndian);
	}

	T get_local(T)(uint addr) {
		return locals[addr].peek!(T, Endian.bigEndian);
	}

	Stack_Frame push_frame() {
		auto frame = new Stack_Frame(this);
		frame.parent = current_frame;
		current_frame = frame;
		return frame;
	}

	Stack_Frame pop_frame() {
		auto old = current_frame;
		current_frame = current_frame.parent;
		return old;
	}
}