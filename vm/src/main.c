#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>

#define ARRAY_SIZEOF(x) (sizeof(x) / sizeof(x[0]))

#include "stack_frame.h"
#include "opcodes.h"
#include "krugvm.h"
#include "array.h"
#include "vthread.h"

#include "opcode_names.h"

/*
	
	this vm is not documented whatsoever other than
	the comments in the opcodes.

	the vm is a stack based virtual machine. the trade off
	here is there are more instructions, and the code generation
	will be a bit simpler. in addition there is no need for
	a register allocator
	
*/

struct Execution_Engine {
	struct array* threads;

	struct Virtual_Thread* main;
	struct Virtual_Thread* thread;

	uint8_t* program;
};

struct Virtual_Thread* 
make_thread(struct Execution_Engine* engine) {
	struct Virtual_Thread* new_thread = malloc(sizeof(*new_thread));
	new_thread->program_counter = 0;
	new_thread->stack_ptr = 0;
	// init thread...

	array_add(engine->threads, new_thread);
	engine->thread = new_thread;

	return new_thread;
}

static void 
initialise_engine(struct Execution_Engine* engine, uint8_t* program) {
	engine->threads = new_array(2);
	engine->main = make_thread(engine);
	engine->program = program;
}

static void
destroy_engine(struct Execution_Engine* engine) {
	// destroy all the threads.
	for (size_t i = 0; i < engine->threads->size; i++) {
		struct Virtual_Thread* thread = array_get(engine->threads, i);
		destroy_thread(thread);
	}
	destroy_array(engine->threads);
}

static uint64_t 
peek_uint64(struct Execution_Engine* engine) {
	uint8_t* instr = &engine->program[engine->thread->program_counter];
	uint64_t value = 
		((uint64_t)(instr[0]) << 56) | 
		((uint64_t)(instr[1]) << 48) | 
		((uint64_t)(instr[2]) << 40) |
		((uint64_t)(instr[3]) << 32) |
		((uint64_t)(instr[4]) << 24) |
		((uint64_t)(instr[5]) << 16) |
		((uint64_t)(instr[6]) << 8) |
		instr[7];
	engine->thread->program_counter += sizeof(uint64_t);
	return value;
}

static int64_t 
peek_int64(struct Execution_Engine* engine) {
	uint8_t* instr = &engine->program[engine->thread->program_counter];
	int64_t value =
		((int64_t)(instr[0]) << 56) | 
		((int64_t)(instr[1]) << 48) | 
		((int64_t)(instr[2]) << 40) |
		((int64_t)(instr[3]) << 32) |
		((int64_t)(instr[4]) << 24) |
		((int64_t)(instr[5]) << 16) |
		((int64_t)(instr[6]) << 8) |
		instr[7];
	engine->thread->program_counter += sizeof(int64_t);
	return value;
}

static uint32_t 
peek_uint32(struct Execution_Engine* engine) {
	uint8_t* instr = &engine->program[engine->thread->program_counter];
	uint32_t value = 
		(instr[0] << 24) | 
		(instr[1] << 16) | 
		(instr[2] << 8) |
		instr[3];
	engine->thread->program_counter += sizeof(uint32_t);
	return value;
}

static int32_t 
peek_int32(struct Execution_Engine* engine) {
	uint8_t* instr = &engine->program[engine->thread->program_counter];
	int32_t value = 
		(instr[0] << 24) | 
		(instr[1] << 16) | 
		(instr[2] << 8) |
		instr[3];
	engine->thread->program_counter += sizeof(int32_t);
	return value;
}

static uint16_t 
peek_uint16(struct Execution_Engine* engine) {
	uint8_t* instr = &engine->program[engine->thread->program_counter];
	uint16_t value = (instr[0] << 8) | instr[1];
	engine->thread->program_counter += sizeof(uint16_t);
	return value;
}

static int16_t 
peek_int16(struct Execution_Engine* engine) {
	uint8_t* instr = &engine->program[engine->thread->program_counter];
	int16_t value = (instr[0] << 8) | instr[1];
	engine->thread->program_counter += sizeof(int16_t);
	return value;
}

#define MAKE_WRITE_TO_TYPE(TYPE)                                     									\
void write_from_##TYPE (uint8_t* data, size_t start, TYPE t) { 												\
	size_t type_width = sizeof(t);																											\
	for (size_t i = 0; i < type_width; i++) {																						\
		data[start + i] = (t >> ((type_width - i - 1) * 8)) & 0xff;												\
	}																																										\
}

#define MAKE_PUSH_TYPE(TYPE)                                     											\
size_t stack_push_##TYPE (uint8_t* data, size_t* ptr, TYPE t) { 											\
	size_t index = *ptr;																																\
	assert(*ptr < STACK_SIZE);																													\
	write_from_##TYPE(data, *ptr, t);																										\
	*ptr += sizeof(TYPE);																																\
	return index;																																				\
}

#define MAKE_BYTESTR_TO_TYPE(TYPE)	\
TYPE bytestr_to_##TYPE (uint8_t* data, size_t start) {					 											\
	size_t type_width = sizeof(TYPE);																										\
	TYPE result = 0;																																		\
	for (size_t i = 0; i < type_width; i++) {																						\
		result = result << 8;																															\
		result |= data[start - (type_width - i)] & 0xff;																	\
	}																																										\
	return result;																																			\
}

#define MAKE_POP_TYPE(TYPE)                                     											\
TYPE stack_pop_##TYPE (uint8_t* data, size_t* ptr) {						 											\
	TYPE result = bytestr_to_##TYPE(data, *ptr);																				\
	*ptr -= sizeof(TYPE);																																\
	return result;																																			\
}

MAKE_BYTESTR_TO_TYPE(uint8_t);
MAKE_BYTESTR_TO_TYPE(uint16_t);
MAKE_BYTESTR_TO_TYPE(uint32_t);
MAKE_BYTESTR_TO_TYPE(uint64_t);
MAKE_BYTESTR_TO_TYPE(int8_t);
MAKE_BYTESTR_TO_TYPE(int16_t);
MAKE_BYTESTR_TO_TYPE(int32_t);
MAKE_BYTESTR_TO_TYPE(int64_t);

MAKE_WRITE_TO_TYPE(uint8_t);
MAKE_WRITE_TO_TYPE(uint16_t);
MAKE_WRITE_TO_TYPE(uint32_t);
MAKE_WRITE_TO_TYPE(uint64_t);
MAKE_WRITE_TO_TYPE(int8_t);
MAKE_WRITE_TO_TYPE(int16_t);
MAKE_WRITE_TO_TYPE(int32_t);
MAKE_WRITE_TO_TYPE(int64_t);

MAKE_PUSH_TYPE(uint8_t);
MAKE_POP_TYPE(uint8_t);
MAKE_PUSH_TYPE(uint16_t);
MAKE_POP_TYPE(uint16_t);
MAKE_PUSH_TYPE(uint32_t); 
MAKE_POP_TYPE(uint32_t);
MAKE_PUSH_TYPE(uint64_t); 
MAKE_POP_TYPE(uint64_t);

MAKE_PUSH_TYPE(int8_t);
MAKE_POP_TYPE(int8_t);
MAKE_PUSH_TYPE(int16_t); 	
MAKE_POP_TYPE(int16_t);
MAKE_PUSH_TYPE(int32_t); 	
MAKE_POP_TYPE(int32_t);
MAKE_PUSH_TYPE(int64_t); 	
MAKE_POP_TYPE(int64_t);

// push/pop helper macros for the engines thread.
// this is kinda dangerous but it makes the code
// a bit easier to read.
#define thread_stack_push(TYPE, thread, args...) stack_push_##TYPE(thread->stack, &(thread->stack_ptr), args) 
#define thread_stack_pop(TYPE, thread) stack_pop_##TYPE(thread->stack, &(thread->stack_ptr)) 

// how many calls have been done in the lifetime
// of the program.
uint64_t num_calls = 0;

bool kill_flag = false;

static void
interpret_instruction(struct Execution_Engine* engine, uint16_t op_code) {
	static size_t last_call_return_addr = 0;

	switch (op_code) {
		case ENTR: {
			struct Stack_Frame* frame = push_frame(engine->thread);
			frame->return_addr = last_call_return_addr;
			break;
		}
		case DIE: {
			kill_flag = true;
			break;
		}
		case CALL: {
			uint32_t addr = peek_uint32(engine);
			last_call_return_addr = engine->thread->program_counter;
			engine->thread->program_counter = addr;
			num_calls++;
			break;
		}
		case RET: {
			struct Stack_Frame* prev = engine->thread->curr_frame;
			pop_frame(engine->thread);

			if (prev->parent == NULL) {
				// we dont really have anything else
				// to do?
				kill_flag = true;
				return;
			}

			if (prev != NULL && engine->thread->curr_frame != NULL) {
				engine->thread->program_counter = prev->return_addr;
			}
			break;
		}
		case CMPI: {
			int32_t b = thread_stack_pop(int32_t, engine->thread);
			int32_t a = thread_stack_pop(int32_t, engine->thread);
			thread_stack_push(int32_t, engine->thread, a == b);
			break;
		}
		case GTRI: {
			int32_t b = thread_stack_pop(int32_t, engine->thread);
			int32_t a = thread_stack_pop(int32_t, engine->thread);
			thread_stack_push(int32_t, engine->thread, a > b);
			break;
		}
		case LTI: {
			int32_t b = thread_stack_pop(int32_t, engine->thread);
			int32_t a = thread_stack_pop(int32_t, engine->thread);
			thread_stack_push(int32_t, engine->thread, a < b);
			break;
		}
		case ADDI: {
			int32_t b = thread_stack_pop(int32_t, engine->thread);
			int32_t a = thread_stack_pop(int32_t, engine->thread);
			thread_stack_push(int32_t, engine->thread, a + b);
			break;
		}
		case MULI: {
			int32_t b = thread_stack_pop(int32_t, engine->thread);
			int32_t a = thread_stack_pop(int32_t, engine->thread);
			thread_stack_push(int32_t, engine->thread, a * b);
			break;
		}
		case SUBI: {
			int32_t b = thread_stack_pop(int32_t, engine->thread);
			int32_t a = thread_stack_pop(int32_t, engine->thread);
			thread_stack_push(int32_t, engine->thread, a - b);
			break;
		}
		case AND: {
			uint8_t b = thread_stack_pop(uint8_t, engine->thread);
			uint8_t a = thread_stack_pop(uint8_t, engine->thread);
			thread_stack_push(uint8_t, engine->thread, a && b);
			break;
		}
		case OR: {
			uint8_t b = thread_stack_pop(uint8_t, engine->thread);
			uint8_t a = thread_stack_pop(uint8_t, engine->thread);
			thread_stack_push(uint8_t, engine->thread, a || b);
			break;
		}
		case GOTO: {
			uint32_t addr = peek_uint32(engine);
			engine->thread->program_counter = addr;
			break;
		}
		case LDI: {
			uint32_t addr = peek_uint32(engine);

			struct Stack_Frame* curr_frame = engine->thread->curr_frame;
			assert(curr_frame != NULL);

			uint8_t raw[sizeof(int32_t)];
			memcpy(raw, &curr_frame->locals[addr], sizeof(int32_t));
			memmove(&engine->thread->stack[engine->thread->stack_ptr], raw, sizeof(int32_t));
			engine->thread->stack_ptr += sizeof(int32_t);

			break;
		}
		case ALLOCI: {
			int32_t value = thread_stack_pop(int32_t, engine->thread);
			uint8_t bytes[sizeof(int32_t)];
			write_from_int32_t(&bytes[0], 0, value);
			struct Stack_Frame* curr_frame = engine->thread->curr_frame;
			memmove(&curr_frame->locals[curr_frame->local_ptr], bytes, sizeof(int32_t));
			curr_frame->local_ptr += sizeof(int32_t);			
			break;
		}
		case STRI: {
			uint32_t addr = peek_uint32(engine);
			int32_t value = thread_stack_pop(int32_t, engine->thread);

			uint8_t bytes[sizeof(int32_t)];
			write_from_int32_t(&bytes[0], 0, value);
			struct Stack_Frame* curr_frame = engine->thread->curr_frame;
			memmove(&curr_frame->locals[addr], bytes, sizeof(int32_t));

			break;
		}
		case JNE: {
			uint32_t addr = peek_uint32(engine);
			if (stack_pop_uint8_t(engine->thread->stack, &engine->thread->stack_ptr) == 0) {
				engine->thread->program_counter = addr;
			}
			break;
		}
		case JE: {
			uint32_t addr = peek_uint32(engine);
			if (stack_pop_uint8_t(engine->thread->stack, &engine->thread->stack_ptr)) {
				engine->thread->program_counter = addr;
			}
			break;
		}
		case PSHI: {
			uint32_t value = peek_uint32(engine);
			stack_push_uint32_t(engine->thread->stack, &engine->thread->stack_ptr, value);
			printf("Pushed %d\n", value);
			break;
		}
		default: {
			printf("unimplemented opcode %s(%d)\n", OPCODE_NAMES[op_code], op_code);
			exit(33);
			break;
		}
	}
}

void 
do_tests() {
	printf("Running tests!\n");

	struct Execution_Engine test_engine;
	initialise_engine(&test_engine, NULL);

	struct Virtual_Thread* test_thread = make_thread(&test_engine);
	push_frame(test_thread);
	{
		printf("- Testing push/pop uint64_t ");
		uint64_t b = 245892;
		uint64_t a = 245892345423;

		thread_stack_push(uint64_t, test_thread, a);
		thread_stack_push(uint64_t, test_thread, b);

		assert(thread_stack_pop(uint64_t, test_thread) == b);
		assert(thread_stack_pop(uint64_t, test_thread) == a);

		thread_stack_push(uint64_t, test_thread, a);
		thread_stack_push(uint64_t, test_thread, b);

		uint64_t popped_b = thread_stack_pop(uint64_t, test_thread);
		uint64_t popped_a = thread_stack_pop(uint64_t, test_thread);
		assert(popped_b * popped_a == b * a);

		printf(" [x]\n");
	}

	destroy_engine(&test_engine);
}

bool 
execute_program(size_t entry_addr, size_t program_size, uint8_t* program) {
	struct Execution_Engine engine;
	initialise_engine(&engine, program);

	printf("Executing %zd byte program\n", program_size);

	// do_tests();

	engine.thread->program_counter = entry_addr;
	while (!kill_flag && engine.thread->program_counter < program_size) {
		uint16_t op_code = peek_uint16(&engine);
		interpret_instruction(&engine, op_code);
	}

	printf("%lld procedures called!\n", num_calls);
	return false;
}