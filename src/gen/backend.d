module gen.backend;

import std.stdio : File;

import kir.ir_mod;

interface Generated_Output {
	File write();
}

interface Backend_Driver {
	void write(Generated_Output[] output);
	Generated_Output code_gen(IR_Module mod);
}