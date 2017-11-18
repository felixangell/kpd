module exec.virtual_thread;

import exec.exec_engine;
import exec.stack_frame;

struct Virtual_Thread {
	ubyte[STACK_SIZE] stack;
	uint stack_ptr = 0;

	ubyte[DATA_SEGMENT_SIZE] globals;

	Stack_Frame current_frame;
	uint program_counter = 0;

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