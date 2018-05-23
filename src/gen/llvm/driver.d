module gen.llvm.driver;

import std.stdio;
import std.process;
import std.path;
import std.file;
import std.string : toStringz;
import std.random;
import std.conv : to;

import cflags;
import logger;
import kir.ir_mod;

import gen.backend;
import gen.x64.link;
import gen.llvm.writer;
import gen.llvm.ir;

class LLVM_Gen_Output : Generated_Output {
	LLVMModuleRef llvm_mod;
	LLVMTargetMachineRef target_machine;

	this(LLVMModuleRef llvm_mod, LLVMTargetMachineRef target_machine) {
		this.llvm_mod = llvm_mod;
		this.target_machine = target_machine;
	}

	// TODO write as llvm ir or asm
	// for now lets write it as asm
	override File write() {
		LLVMMemoryBufferRef buff;
		LLVMString error;
		LLVMTargetMachineEmitToMemoryBuffer(target_machine, llvm_mod, 
			LLVMCodeGenFileType.LLVMObjectFile,  // FIXME!!
			&error, &buff);

		auto st = LLVMGetBufferStart(buff);
		auto end = LLVMGetBufferSize(buff);

		auto data = cast(immutable(byte)*)(st)[0..end];


		string file_name = "krug-llvm-asm-" ~ thisProcessID.to!string(36) ~ "-" ~ uniform!uint.to!string(36) ~ ".as";
		auto temp_file = File(file_name, "wb");
		writeln("LLVM Assembly file '", temp_file.name, "' created.");
		temp_file.rawWrite(cast(byte[])(data[0..end]));
		temp_file.close();

		if (VERBOSE_LOGGING) LLVMDumpModule(llvm_mod);
		return temp_file;
	}
}

class LLVM_Driver : Backend_Driver {
	LLVMTargetRef target;
	LLVMTargetMachineRef target_machine;

	this() {
		LLVMInitializeX86TargetInfo();
		LLVMInitializeX86Target();
		LLVMInitializeX86TargetMC();
		LLVMInitializeX86AsmPrinter();
		LLVMInitializeX86AsmParser();

		auto triple = LLVMGetDefaultTargetTriple();
		scope(exit) LLVMDisposeMessage(triple);

		// todo error check me!
		LLVMString error;
		auto res = LLVMGetTargetFromTriple(triple, &target, &error);
		assert(res == 0, to!string(error));

		target_machine = LLVMCreateTargetMachine(target, triple, "".toStringz, "".toStringz, LLVMCodeGenOptLevel.LLVMCodeGenLevelNone, LLVMRelocMode.LLVMRelocDefault, LLVMCodeModel.LLVMCodeModelDefault);
	}

	override void write(Generated_Output[] output) {
		File[] obj_files;
		scope(exit) {
			foreach (f; obj_files) {
				remove(f.name);
			}
		}

		string[] obj_file_paths;
		foreach (o; output) {
			auto obj_file = o.write();
			obj_files ~= obj_file;
			obj_file_paths ~= absolutePath(obj_file.name);
		}

		Linker_Info info;
		info.add_flags("-lc", "-fPIC", "-no-pie");
		link_objs("/usr/bin/gcc", info, obj_file_paths, OUT_NAME);
	}

	override LLVM_Gen_Output code_gen(IR_Module mod) {
		auto writer = new LLVM_Writer(mod);
		// run passes with a PassManager thing
		auto output = writer.gen(target_machine);
		LLVMString error;
		LLVMVerifyModule(output.llvm_mod, LLVMVerifierFailureAction.LLVMAbortProcessAction, &error);
		writeln(to!string(error));
		return output;
	} 
}