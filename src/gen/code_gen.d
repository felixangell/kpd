module gen.code_gen;

import std.conv;

import gen.backend;
import gen.target;

import gen.clang;

import kir.ir_mod;

import logger;

void generate_code(Target t, IR_Module[] modules) {
	Backend_Driver backend;
	final switch (t) {
	case Target.CLANG:
		backend = new CLANG_Driver;
		break;
	}

	Generated_Output[] output_program;
	logger.verbose_header("Generating code for ", to!string(modules.length), " modules");
	foreach (ref mod; modules) {
		output_program ~= backend.code_gen(mod);
	}
	logger.verbose_header("Writing generated code");
	backend.write(output_program);
}