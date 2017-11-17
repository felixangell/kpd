module exec.stack_frame;

import exec.virtual_thread;

struct Stack_Frame {
	Virtual_Thread parent_thread;
}