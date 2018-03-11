module opt.opt_manager;

import opt.pass;
import opt.constant_prop;

import logger;
import kir.ir_mod;
import kir.instr;

void optimise(Kir_Module[] program, int level) {
	Optimisation_Pass[] passes;
	final switch (level) {
	case -1:
		passes = []; // no optimisations at all!
		break;
	case 0:
		passes = [
			new Constant_Prop,
		]; // minimal passes
		break;
	}

	foreach (ref mod; program) {
		foreach (ref pass; passes) {
			pass.process(mod);
		}
	}
}