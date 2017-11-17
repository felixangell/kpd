module exec.virtual_thread;

import exec.stack_frame;

const auto KILOBYTE = 1000;
const auto MEGABYTE = KILOBYTE * 1000;
const auto STACK_SIZE = MEGABYTE * 1;
const auto DATA_SEGMENT_SIZE = MEGABYTE * 1;

struct Virtual_Thread {
	byte[STACK_SIZE] stack;
	uint stack_ptr = 0;

	byte[DATA_SEGMENT_SIZE] globals;

	Stack_Frame current_frame;
	uint program_counter = 0;

	Stack_Frame push_frame() {
		auto frame = Stack_Frame(this);
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