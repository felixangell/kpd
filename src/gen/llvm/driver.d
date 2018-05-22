module gen.llvm.driver;

import kir.ir_mod;
import gen.backend;
import gen.llvm.writer;

class LLVM_Gen_Output : Generated_Output {}

class LLVM_Driver : Code_Generator_Backend {
	override void write(Generated_Output[] output) {

	}

	override LLVM_Gen_Output code_gen(IR_Module mod) {
		auto writer = new LLVM_Writer(mod);
		return writer.gen();
	} 
}