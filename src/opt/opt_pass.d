module opt.pass;

import kir.ir_mod;

interface Optimisation_Pass {
	void process(Kir_Module mod);

	// overriding to!string
	string toString();
}