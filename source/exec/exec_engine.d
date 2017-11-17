module exec.exec_engine;

import exec.virtual_thread;

class Execution_Engine {
	Virtual_Thread[] stack;
	Virtual_Thread main, current;

	this() {
		stack ~= main;
		current = main;
	}
}