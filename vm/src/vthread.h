#ifndef VTHREAD_H
#define VTHREAD_H

#include <stdint.h>
#include <stddef.h>

struct Stack_Frame;

#include "sizes.h"

#define BYTE_SIZE 1
#define SHORT_SIZE 2
#define INT_SIZE 4
#define LONG_SIZE 8

struct Virtual_Thread {
	uint8_t globals[DATA_SEGMENT_SIZE];
	uint8_t stack[STACK_SIZE];

	struct Stack_Frame* curr_frame;
	size_t program_counter;
};

struct Stack_Frame* 
push_frame(struct Virtual_Thread* thread);

struct Stack_Frame* 
pop_frame(struct Virtual_Thread* thread);

#endif 