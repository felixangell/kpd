#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <collectc/array.h>

#define ARRAY_SIZEOF(x) (sizeof(x) / sizeof(x[0]))

#include "opcodes.h"
#include "krugvm.h"
#include "vthread.h"

static unsigned char* program[] = {
	#include "test_program.c.inc"
};

struct Execution_Engine {
	Array* frames;

	struct Virtual_Thread* main;
	struct Virtual_Thread* thread;

	unsigned char** program;
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

void 
initialise_engine(struct Execution_Engine* engine, unsigned char** program) {
	engine->main = make_thread(engine);
	engine->program = program;
}

bool 
execute_program(size_t entry_addr, size_t instruction_count, unsigned char** program) {
	struct Execution_Engine engine;
	initialise_engine(&engine, program);

	engine.thread->program_counter = entry_addr;
	while (engine.thread->program_counter < instruction_count) {
		unsigned char* instruction = program[engine.thread->program_counter++];
		uint16_t op_code = (instruction[0] << 8) | instruction[1];
		switch (op_code) {
			case ENTR: {
				printf("enter baby!\n");
				break;
			default:
				printf("unimplemented opcode %d\n", op_code);
				break;
			}
		}
	}
	return false;
}

int 
main() {
	printf("Execute program?!\n");
	execute_program(0, ARRAY_SIZEOF(program), program);
	return 0;
}