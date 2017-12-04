module exec.exec_engine;

import std.conv;

import err_logger;

import exec.virtual_thread;
import exec.instruction;

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

	Instruction[] program;

	this(Instruction[] program, uint entryAddr = 0) {
		this.program = program;

		stack ~= main;
		current = main;

		current.program_counter = entryAddr;
		while (current.program_counter < program.length) {
			auto curr = next();
			switch (curr.id) {
			default:
				err_logger.Fatal("unhandled instr " ~ to!string(curr));
				break;
			}
		}
	}

	Instruction next() {
		return program[current.program_counter++];
	}
}