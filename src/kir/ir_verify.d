module kir.ir_verify;

import kir.ir_mod;

import logger;

// a simple IR verifier to check everything is sound
// the errors here are not to be shown to the _user_
// and are mostly an indicator of compiler bugs.
class IR_Verifier {

	Kir_Module mod;

	this(Kir_Module mod) {
		this.mod = mod;
		verify(mod);
	}

	void verify(Kir_Module mod) {
		
	}

}