#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <collectc/array.h>

#define ARRAY_SIZEOF(x) (sizeof(x) / sizeof(x[0]))

#include "opcodes.h"
#include "krugvm.h"
#include "vthread.h"

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
			printf("enter baby!\n");
			break;
		}
		default: {
			printf("unimplemented opcode %d\n", op_code);
			break;
		}
	}
}

bool 
execute_program(size_t entry_addr, size_t program_size, unsigned char* program) {
	struct Execution_Engine engine;
	initialise_engine(&engine, program);

	for (int i = 0; i < program_size; i++) {
		if (i > 0 && i % 4 == 0) {
			printf("\n");
		}
		printf("%02x ", program[i]);
	}
	printf("\n");

	printf("Executing %zd byte program\n", program_size);

	engine.thread->program_counter = entry_addr;
	while (engine.thread->program_counter < program_size) {
		uint16_t op_code = peek_uint16(&engine);
		printf("op_code: %d\n", op_code);
		interpret_instruction(&engine, op_code);
		return false;
	}
	return false;
}