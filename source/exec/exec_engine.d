module exec.exec_engine;

import std.conv;

import err_logger;

import exec.virtual_thread;
import exec.instruction;
import exec.stack_frame;
import exec.byte_stack;

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
			
			Byte_Stack cache;
			
			{
				auto stack_frame = curr_stack_frame();
				Byte_Stack* stack = &stack_frame.parent_thread.stack;

				// we ARE in a function!
				if (stack !is null) {
					// pop the return address which is where
					// we have come from
					stack_frame.return_addr = stack.pop!uint();

					err_logger.Info("caching stack!");
					while (!stack.is_empty()) {
						err_logger.Info("caching stack, stack_ptr is " ~ to!string(stack.stack_ptr));
						cache.push!ubyte(stack.pop!ubyte());
					}
				}
			}

			{
				// push a frame!
				current.push_frame();
				auto stack_frame = curr_stack_frame();
				Byte_Stack* stack = &stack_frame.parent_thread.stack;

				// first thing we have to do is put 
				// all of the contents of the 
				// cache into this stack frame.
				while (!cache.is_empty()) {
					err_logger.Info("restoring cache");
					ubyte popped = cache.pop!ubyte();
					stack.push!ubyte(popped);
				}

				err_logger.Info("pushing return addr!");
				stack.push!uint(stack_frame.return_addr);				
			}

			break;
		}
		case OP.RET: {
			auto frame = current.pop_frame();
			if (frame.parent !is null) {
				current.program_counter = frame.parent.return_addr;
			}
			break;
		}
		case OP.CALL: {
			auto addr = instr.peek!uint();
			err_logger.Info("Calling function at addr" ~ to!string(addr));
			current.program_counter = addr;
			break;
		}
		case OP.GOTO: {
			auto addr = instr.peek!uint();
			current.program_counter = addr;
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