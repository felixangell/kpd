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
	Virtual_Thread main, thread;

	Instruction[] program;

	uint call_ret_addr = 0;

	this(Instruction[] program, uint entryAddr = 0) {
		this.program = program;

		stack ~= main;
		thread = main;

		err_logger.Verbose("Starting program at addr " ~ to!string(entryAddr));

		thread.program_counter = entryAddr;
		while (thread.program_counter < program.length) {
			execute_instr(next());
		}
	}

	Stack_Frame curr_stack_frame() {
		return thread.current_frame;
	}

	void execute_instr(Instruction instr) {
		switch (instr.id) {
		case OP.ENTR: {			
			Byte_Stack cache;
			
			{
				auto stack_frame = curr_stack_frame();

				// if we've been called from a function
				// then we want to cache the current
				// functions stack
				if (stack_frame !is null) {
					Byte_Stack* stack = &stack_frame.parent_thread.stack;

					// the stack should be empty in theory before we 
					// do a function call, so anything on the stack 
					// is an argument to the function

					err_logger.Info("caching stack!");
					while (!stack.is_empty()) {
						err_logger.Info("caching stack, stack_ptr is " ~ to!string(stack.stack_ptr));
						cache.push!ubyte(stack.pop!ubyte());
					}
				}
			}

			err_logger.Info("Pushing new stack frame");
			{
				thread.push_frame();

				auto stack_frame = curr_stack_frame();
				Byte_Stack* stack = &stack_frame.parent_thread.stack;

				stack_frame.return_addr = call_ret_addr;

				// first thing we have to do is put 
				// all of the contents of the 
				// cache into this stack frame.
				//
				// everything that was cached is the arguments
				// to this function
				while (!cache.is_empty()) {
					err_logger.Info("restoring cache");
					ubyte popped = cache.pop!ubyte();
					stack.push!ubyte(popped);
				}
			}

			break;
		}
		case OP.RET: {
			auto prev_frame = curr_stack_frame();
			thread.pop_frame();

			// HACK? we only jump to a previous frame
			// if there is a stack frame otherwise if
			// we only have a main function for example
			// we'll pop this and there will be no
			// frames left and the program should exit
			if (prev_frame !is null && curr_stack_frame() !is null) {
				// one issue here is this could be zero
				// if we dont have a return address which 
				// may mean the program starts executing again?

				err_logger.Verbose("Jumping to addr" ~ to!string(prev_frame.return_addr));
				thread.program_counter = prev_frame.return_addr;
			}
			break;
		}
		case OP.CALL: {
			auto addr = instr.peek!uint();
			err_logger.Info("Calling function at addr" ~ to!string(addr));
			call_ret_addr = thread.program_counter;
			thread.program_counter = addr;
			break;
		}
		case OP.GOTO: {
			auto addr = instr.peek!uint();
			thread.program_counter = addr;
			break;
		}
		default:
			err_logger.Fatal("unhandled instr " ~ to!string(instr));
			break;
		}
	}

	Instruction next() {
		return program[thread.program_counter++];
	}
}