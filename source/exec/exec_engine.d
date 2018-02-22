module exec.exec_engine;

import std.conv;

import logger;

import exec.virtual_thread;
import exec.instruction;
import exec.stack_frame;
import exec.byte_stack;

const auto KILOBYTE = 1000;
const auto MEGABYTE = KILOBYTE * 1000;

const auto STACK_SIZE = MEGABYTE * 1;
const auto DATA_SEGMENT_SIZE = MEGABYTE * 1;
const auto LOCALS_SIZE = MEGABYTE * 1;

const auto BYTE_SIZE = 1, SHORT_SIZE = 2, INT_SIZE = 4, LONG_SIZE = 8;

class Execution_Engine {
  Virtual_Thread[] stack;
  Virtual_Thread main, thread;

  Instruction[] program;

  uint call_ret_addr = 0;

  this(Instruction[] program, uint entryAddr = 0) {
    this.program = program;

    stack ~= main;
    thread = main;

    logger.Verbose("Starting program at addr " ~ to!string(entryAddr));

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

            logger.Info("caching stack!");
            while (!stack.is_empty()) {
              logger.Info("caching stack, stack_ptr is " ~ to!string(stack.stack_ptr));
              cache.push!ubyte(stack.pop!ubyte());
            }
          }
        }

        logger.Info("Pushing new stack frame");
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
            logger.Info("restoring cache");
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
        //
        // in other words, as soon as the stack frame is
        // null the program should exit because we are
        // not in any functions anymore and there is nothing
        // left to execute.
        //
        // checking the prev_frame is not null is more of
        // a weird error check for rare cases?
        if (prev_frame !is null && curr_stack_frame() !is null) {
          // one issue here is this could be zero
          // if we dont have a return address which 
          // may mean the program starts executing again?

          logger.Verbose("Jumping to addr" ~ to!string(prev_frame.return_addr));
          thread.program_counter = prev_frame.return_addr;
        }
        break;
      }
    case OP.CALL: {
        auto addr = instr.peek!uint();
        logger.Info("Calling function at addr" ~ to!string(addr));
        call_ret_addr = thread.program_counter;
        thread.program_counter = addr;
        break;
      }
    case OP.GOTO: {
        auto addr = instr.peek!uint();
        thread.program_counter = addr;
        break;
      }

    case OP.SUBI: {
        auto b = thread.stack.pop!int();
        auto a = thread.stack.pop!int();
        thread.stack.push!int(a - b);
        break;
      }

    case OP.ADDI: {
        auto b = thread.stack.pop!int();
        auto a = thread.stack.pop!int();
        thread.stack.push!int(a + b);
        break;
      }

    case OP.MULI: {
        auto b = thread.stack.pop!int();
        auto a = thread.stack.pop!int();
        thread.stack.push!int(a * b);
        break;
      }

      // pushes the given value to the
      // operand stack.
      // PSH, PSHS, PSHI, PSHL,
      // 1 byte, 2 byte, 3 byte, 4 byte

    case OP.PSH: {
        auto val = instr.peek!byte();
        thread.stack.push!byte(val);
        break;
      }
    case OP.PSHS: {
        auto val = instr.peek!short();
        thread.stack.push!short(val);
        break;
      }
    case OP.PSHI: {
        auto val = instr.peek!int();
        thread.stack.push!int(val);
        break;
      }
    case OP.PSHL: {
        auto val = instr.peek!long();
        thread.stack.push!long(val);
        break;
      }

    case OP.AND: {
        auto b = thread.stack.pop!byte();
        auto a = thread.stack.pop!byte();
        thread.stack.push!byte(a && b);
        break;
      }

    case OP.OR: {
        auto b = thread.stack.pop!byte();
        auto a = thread.stack.pop!byte();
        thread.stack.push!byte(a || b);
        break;
      }

    case OP.GTR: {
        auto b = thread.stack.pop!byte();
        auto a = thread.stack.pop!byte();
        thread.stack.push!byte(a > b);
        break;
      }

    case OP.GTRS: {
        auto b = thread.stack.pop!short();
        auto a = thread.stack.pop!short();
        thread.stack.push!byte(a > b);
        break;
      }

    case OP.GTRI: {
        auto b = thread.stack.pop!int();
        auto a = thread.stack.pop!int();
        thread.stack.push!byte(a > b);
        break;
      }

    case OP.GTRL: {
        auto b = thread.stack.pop!long();
        auto a = thread.stack.pop!long();
        thread.stack.push!byte(a > b);
        break;
      }

    case OP.CMP: {
        // because it's a stack we have to 
        // pop b first then a, because some
        // operations are not symmetrical
        auto b = thread.stack.pop!byte();
        auto a = thread.stack.pop!byte();
        thread.stack.push!byte(a == b);
        break;
      }
    case OP.CMPS: {
        auto b = thread.stack.pop!short();
        auto a = thread.stack.pop!short();
        thread.stack.push!byte(a == b);
        break;
      }
    case OP.CMPI: {
        auto b = thread.stack.pop!int();
        auto a = thread.stack.pop!int();
        thread.stack.push!byte(a == b);
        break;
      }
    case OP.CMPL: {
        auto b = thread.stack.pop!long();
        auto a = thread.stack.pop!long();
        thread.stack.push!byte(a == b);
        break;
      }

    case OP.JE: {
        auto top = thread.stack.pop!byte();
        auto addr = instr.peek!uint();
        if (top) {
          thread.program_counter = addr;
        }
        break;
      }

    case OP.JNE: {
        auto top = thread.stack.pop!byte();
        auto addr = instr.peek!uint();
        if (!top) {
          thread.program_counter = addr;
        }
        break;
      }

    case OP.LDI: {
        auto addr = instr.peek!uint();
        auto val = thread.current_frame.get_local!uint(addr);
        thread.stack.push(val);
        logger.Verbose("Loaded " ~ to!string(val) ~ " from addr " ~ to!string(addr));
        break;
      }

    case OP.ALLOCI: {
        auto val = thread.stack.pop!int();
        auto addr = thread.current_frame.alloc_local!int(val);
        logger.Verbose("Alloc'd local " ~ to!string(val) ~ " at addr " ~ to!string(addr));
        break;
      }

    case OP.STRI: {
        auto addr = instr.peek!uint();
        auto val = thread.stack.pop!int();
        thread.current_frame.store_local!int(val, addr);
        logger.Verbose("Stored " ~ to!string(val) ~ " at addr " ~ to!string(addr));
        break;
      }

    default:
      logger.Fatal("unhandled instr " ~ to!string(instr));
      break;
    }
  }

  Instruction next() {
    return program[thread.program_counter++];
  }
}
