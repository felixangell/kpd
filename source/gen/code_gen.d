module gen.code_gen;

import std.conv;

import gen.backend;
import gen.x64.backend;
import gen.target;

import kir.ir_mod;

import logger;

void generate_code(Target t, Kir_Module[] modules) {
	Code_Generator_Backend backend;
	final switch (t) {
	case Target.X64:
		backend = new X64_Backend;
		break;
	}

	Generated_Output[] output_program;
	logger.VerboseHeader("Generating code for ", to!string(modules.length), " modules");
	foreach (ref mod; modules) {
		output_program ~= backend.code_gen(mod);
	}
	logger.VerboseHeader("Writing generated code");
	backend.write(output_program);
}