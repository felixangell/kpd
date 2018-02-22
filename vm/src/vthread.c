#include <stdio.h>
#include <stdlib.h>

#include "vthread.h"
#include "stack_frame.h"

void 
destroy_thread(struct Virtual_Thread* thread) {
	struct Stack_Frame* frame = thread->curr_frame;
	while (frame != NULL) {
		struct Stack_Frame* frame_to_destroy = frame;
		frame = frame->parent;
		free(frame_to_destroy);
	}
	free(thread);
}

struct Stack_Frame* 
push_frame(struct Virtual_Thread* thread) {
	struct Stack_Frame* frame = malloc(sizeof(*frame));
	frame->parent_thread = thread;
	frame->parent = thread->curr_frame;
	thread->curr_frame = frame;
	printf("Pushed stack frame\n");
	return frame;
}

struct Stack_Frame* 
pop_frame(struct Virtual_Thread* thread) {
	struct Stack_Frame* old_frame = thread->curr_frame;
	if (thread->curr_frame != NULL) {
		thread->curr_frame = thread->curr_frame->parent;
	}
	printf("Popped stack frame\n");
	return old_frame;
}