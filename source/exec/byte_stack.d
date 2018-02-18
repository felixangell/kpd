module exec.byte_stack;

import std.conv;
import std.bitmanip;

import exec.exec_engine;

struct Byte_Stack {

  size_t stack_ptr = -1;
  ubyte[STACK_SIZE] data;

  void push(T)(T val) {
    stack_ptr += T.sizeof;
    write!(T)(data[], val, stack_ptr);
  }

  bool is_empty() {
    return stack_ptr == -1;
  }

  T pop(T)() {
    T value = peek!T(data[stack_ptr .. stack_ptr + T.sizeof]);
    stack_ptr -= T.sizeof;
    return value;
  }

}
