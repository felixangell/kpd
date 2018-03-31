module gen.backend;

import kir.ir_mod;

interface Generated_Output {}

interface Code_Generator_Backend {
	void write(Generated_Output[] output);
	Generated_Output code_gen(Kir_Module mod);
}