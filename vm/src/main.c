#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#include <collectc/array.h>

#define ARRAY_SIZEOF(x) (sizeof(x) / sizeof(x[0]))

#include "stack_frame.h"
#include "opcodes.h"
#include "krugvm.h"
#include "vthread.h"

#include "opcode_names.h"

struct Execution_Engine {
	Array* threads;

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
	array_new(&engine->threads);
	engine->main = make_thread(engine);
	engine->program = program;
}

static void
destroy_engine(struct Execution_Engine* engine) {
	// destroy all the threads.
	for (size_t i = 0; i < array_size(engine->threads); i++) {
		struct Virtual_Thread* thread;
		array_get_at(engine->threads, i, (void*) &thread);
		destroy_thread(thread);
	}
	array_destroy(engine->threads);
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

#define MAKE_PUSH_TYPE(TYPE)                                     											\
void stack_push_##TYPE (struct Virtual_Thread* thread, TYPE t){ 											\
	size_t type_width = sizeof(t);																											\
	for (size_t i = 0; i < type_width; i++) {																						\
		thread->stack[thread->stack_ptr + i] = (t >> ((type_width - i - 1) * 8)) & 0xff;	\
	}																																										\
	thread->stack_ptr += type_width;																										\
}

#define MAKE_POP_TYPE(TYPE)                                     											\
TYPE stack_pop_##TYPE (struct Virtual_Thread* thread) {					 											\
	size_t type_width = sizeof(TYPE);																											\
	TYPE result = 0;																																		\
	for (size_t i = 0; i < type_width; i++) {																							\
		result = result << 8;																															\
		result |= thread->stack[thread->stack_ptr - (type_width - i)] & 0xff;														\
	}																																										\
	thread->stack_ptr -= type_width;																										\
	return result;																																			\
}

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

static void
interpret_instruction(struct Execution_Engine* engine, uint16_t op_code) {
	static size_t last_call_return_addr = 0;

	switch (op_code) {
		case ENTR: {
			struct Stack_Frame* frame = push_frame(engine->thread);
			frame->return_addr = last_call_return_addr;
			break;
		}
		case CALL: {
			uint32_t addr = peek_uint32(engine);
			last_call_return_addr = engine->thread->program_counter;
			engine->thread->program_counter = addr;
			break;
		}
		case RET: {
			struct Stack_Frame* prev = engine->thread->curr_frame;
			pop_frame(engine->thread);

			if (prev != NULL && engine->thread->curr_frame != NULL) {
				engine->thread->program_counter = prev->return_addr;
			}
			break;
		}
		case CMPI: {
			int32_t b = stack_pop_int32_t(engine->thread);
			int32_t a = stack_pop_int32_t(engine->thread);
			stack_push_int32_t(engine->thread, b + a);
			break;
		}
		case AND: {
			uint8_t b = stack_pop_uint8_t(engine->thread);
			uint8_t a = stack_pop_uint8_t(engine->thread);
			stack_push_uint8_t(engine->thread, a && b);
			break;
		}
		case OR: {
			uint8_t b = stack_pop_uint8_t(engine->thread);
			uint8_t a = stack_pop_uint8_t(engine->thread);
			stack_push_uint8_t(engine->thread, a || b);
			break;
		}
		case JNE: {
			uint32_t addr = peek_uint32(engine);
			if (stack_pop_uint8_t(engine->thread) == 0) {
				engine->thread->program_counter = addr;
			}
			break;
		}
		case PSHI: {
			uint32_t value = peek_uint32(engine);
			printf("pushing %d\n", value);
			stack_push_uint32_t(engine->thread, value);
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
	{
		printf("- Testing push/pop uint64_t ");
		uint64_t b = 245892;
		uint64_t a = 245892345423;

		stack_push_uint64_t(test_thread, a);
		stack_push_uint64_t(test_thread, b);

		assert(stack_pop_uint64_t(test_thread) == b);
		assert(stack_pop_uint64_t(test_thread) == a);

		stack_push_uint64_t(test_thread, a);
		stack_push_uint64_t(test_thread, b);

		uint64_t popped_b = stack_pop_uint64_t(test_thread);
		uint64_t popped_a = stack_pop_uint64_t(test_thread);
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

	for (size_t i = 0; i < program_size; i++) {
		if (i > 0 && i % 6 == 0) {
			printf("\n");
		}
		printf("%02x ", program[i]);
	}
	printf("...\n");

	do_tests();

	engine.thread->program_counter = entry_addr;
	while (engine.thread->program_counter < program_size) {
		uint16_t op_code = peek_uint16(&engine);
		interpret_instruction(&engine, op_code);
	}
	return false;
}