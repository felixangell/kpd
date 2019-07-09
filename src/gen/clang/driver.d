module gen.clang;

import std.stdio;

import gen.backend : Backend_Driver, Generated_Output;
import kir.ir_mod;

class CLANG_Driver : Backend_Driver {
    void write(Generated_Output[] output) {
        writeln("writing stuff");
    }

    Generated_Output code_gen(IR_Module mod) {
        return null;
    }
}