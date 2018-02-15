module exec.stack_frame;

import std.conv;
import std.bitmanip;

import exec.exec_engine;
import exec.virtual_thread;

class Stack_Frame {
    Virtual_Thread parent_thread;
    Stack_Frame parent;

    ubyte[LOCALS_SIZE] locals;
    uint local_index = 0;
    uint return_addr = 0;

    this(Virtual_Thread parent_thread) {
        this.parent_thread = parent_thread;
    }

    bool is_empty() {
        return parent_thread.stack.stack_ptr == 0;
    }

    void store_local(T)(T value, uint addr) {
        write!(T)(locals[], value, addr);
    }

    uint alloc_local(T)(T value) {
        auto store_addr = local_index;
        write!(T)(locals[], value, local_index);
        local_index += T.sizeof;
        return store_addr;
    }

    T get_local(T)(uint addr) {
        return peek!T(locals[addr .. addr + T.sizeof]);
    }
}
