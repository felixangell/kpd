module exec.exec_engine;

import exec.virtual_thread;

const auto KILOBYTE = 1000;
const auto MEGABYTE = KILOBYTE * 1000;

const auto STACK_SIZE = MEGABYTE * 1;
const auto DATA_SEGMENT_SIZE = MEGABYTE * 1;
const auto LOCALS_SIZE = MEGABYTE * 1;

const auto BYTE_SIZE = 1,
		SHORT_SIZE = 2,
		INT_SIZE = 4,
		LONG_SIZE = 8;

class Execution_Engine {
	Virtual_Thread[] stack;
	Virtual_Thread main, current;

	this() {
		stack ~= main;
		current = main;
	}
}