module opt.pass;

import kir.ir_mod;

interface Optimisation_Pass {
	void process(IR_Module mod);

	// overriding to!string
	string toString();
}