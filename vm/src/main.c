#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <collectc/array.h>

#define ARRAY_SIZEOF(x) (sizeof(x) / sizeof(x[0]))

#include "stack_frame.h"
#include "opcodes.h"
#include "krugvm.h"
#include "vthread.h"

#include "opcode_names.h"

struct Execution_Engine {
	Array* frames;

	struct Virtual_Thread* main;
	struct Virtual_Thread* thread;

	uint8_t* program;
};

struct Virtual_Thread* 
make_thread(struct Execution_Engine* engine) {
	struct Virtual_Thread* new_thread = malloc(sizeof(*new_thread));
	new_thread->program_counter = 0;
	// init thread...

	array_add(engine->frames, new_thread);
	engine->thread = new_thread;

	return new_thread;
}

static void 
initialise_engine(struct Execution_Engine* engine, uint8_t* program) {
	array_new(&engine->frames);
	engine->main = make_thread(engine);
	engine->program = program;
}

static uint64_t peek_uint64(struct Execution_Engine* engine) {
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

static int64_t peek_int64(struct Execution_Engine* engine) {
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

static uint32_t peek_uint32(struct Execution_Engine* engine) {
	uint8_t* instr = &engine->program[engine->thread->program_counter];
	uint32_t value = 
		(instr[0] << 24) | 
		(instr[1] << 16) | 
		(instr[2] << 8) |
		instr[3];
	engine->thread->program_counter += sizeof(uint32_t);
	return value;
}

static int32_t peek_int32(struct Execution_Engine* engine) {
	uint8_t* instr = &engine->program[engine->thread->program_counter];
	int32_t value = 
		(instr[0] << 24) | 
		(instr[1] << 16) | 
		(instr[2] << 8) |
		instr[3];
	engine->thread->program_counter += sizeof(int32_t);
	return value;
}

static uint16_t peek_uint16(struct Execution_Engine* engine) {
	uint8_t* instr = &engine->program[engine->thread->program_counter];
	uint16_t value = (instr[0] << 8) | instr[1];
	engine->thread->program_counter += sizeof(uint16_t);
	return value;
}

static int16_t peek_int16(struct Execution_Engine* engine) {
	uint8_t* instr = &engine->program[engine->thread->program_counter];
	int16_t value = (instr[0] << 8) | instr[1];
	engine->thread->program_counter += sizeof(int16_t);
	return value;
}

static void
interpret_instruction(struct Execution_Engine* engine, uint16_t op_code) {
	switch (op_code) {
		case ENTR: {
			// cache here.
			{
				// if curr frame != null
				// cache frame stack
			}

			struct Stack_Frame* frame = push_frame(engine->thread);
			// set return addr
			// restore cache
			break;
		}
		case RET: {
			struct Stack_Frame* prev = engine->thread->curr_frame;
			pop_frame(engine->thread);

			if (prev != NULL && engine->thread->curr_frame != NULL) {
				// jump back to return addr.
				engine->thread->program_counter = prev->return_addr;
			}
			break;
		}
		default: {
			printf("unimplemented opcode %s(%d)\n", OPCODE_NAMES[op_code], op_code);
			exit(33);
			break;
		}
	}
}

bool 
execute_program(size_t entry_addr, size_t program_size, unsigned char* program) {
	struct Execution_Engine engine;
	initialise_engine(&engine, program);

	printf("Executing %zd byte program\n", program_size);

	engine.thread->program_counter = entry_addr;
	while (engine.thread->program_counter < program_size) {
		uint16_t op_code = peek_uint16(&engine);
		interpret_instruction(&engine, op_code);
	}
	return false;
}