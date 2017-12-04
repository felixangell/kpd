module exec.exec_engine;

import std.conv;

import err_logger;

import exec.virtual_thread;
import exec.instruction;
import exec.stack_frame;

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
			execute_instr(next());
		}
	}

	Stack_Frame curr_stack_frame() {
		return current.current_frame;
	}

	void execute_instr(Instruction instr) {
		switch (instr.id) {
		case OP.ENTR: {
			err_logger.Info("Pushing new stack frame");
			ubyte[] stack_cache;
			
			auto stack = curr_stack_frame();
			if (stack !is null) {
				stack.return_addr = stack.pop!ulong();
			}
			break;
		}
		case OP.RET: {
			break;
		}
		case OP.CALL: {

			break;
		}
		default:
			err_logger.Fatal("unhandled instr " ~ to!string(instr));
			break;
		}
	}

	Instruction next() {
		return program[current.program_counter++];
	}
}