module gen.x64.link;

import std.stdio;
import std.path;
import std.file;
import std.process;

import logger;

/*
 "/usr/bin/ld" 
 --hash-style=both 
 --eh-frame-hdr 
 -m elf_x86_64 
 -dynamic-linker 

/lib64/ld-linux-x86-64.so.2 
-o a.out 
/usr/bin/../lib/gcc/x86_64-linux-gnu/7.2.0/../../../x86_64-linux-gnu/crt1.o 
/usr/bin/../lib/gcc/x86_64-linux-gnu/7.2.0/../../../x86_64-linux-gnu/crti.o 
/usr/bin/../lib/gcc/x86_64-linux-gnu/7.2.0/crtbegin.o 
-L/usr/bin/../lib/gcc/x86_64-linux-gnu/7.2.0 
-L/usr/bin/../lib/gcc/x86_64-linux-gnu/7.2.0/../../../x86_64-linux-gnu
-L/lib/x86_64-linux-gnu 
-L/lib/../lib64 
-L/usr/lib/x86_64-linux-gnu
-L/usr/bin/../lib/gcc/x86_64-linux-gnu/7.2.0/../../.. 
-L/usr/lib/llvm-4.0/bin/../lib -L/lib -L/usr/lib test.o 
-L/home/felix/dlang/dmd-2.079.0/linux/lib64 -L.
-lgcc
-lgcc_s 
-lc 
-lgcc 
-lgcc_s 

  /usr/bin/../lib/gcc/x86_64-linux-gnu/7.2.0/crtend.o 
  /usr/bin/../lib/gcc/x86_64-linux-gnu/7.2.0/../../../x86_64-linux-gnu/crtn.o
 */

struct Linker_Info {
	string[] flags;
	string[] objects;
}

void add_flags(ref Linker_Info info, string[] flags...) {
	foreach (f; flags) {
		info.flags ~= f;
	}
}

void add_objs(ref Linker_Info info, string[] obj...) {
	foreach (o; obj) {
		info.objects ~= o;
	}
}

void find_gcc() {

}

void find_libs() {

}

void find_incl() {

}

/*
	First step is find the gcc installation!
*/
Linker_Info link_objs_linux() {
	logger.Verbose("Linking for POSIX");

	Linker_Info info;
	info.add_flags(
		"--hash-style=both",
		"--eh-frame-hdr",
		"-dynamic-linker",
		"-melf_x86_64"); // FIXME
	return info;
}

Linker_Info link_objs_osx() {
	logger.Verbose("Linking for OSX");

	Linker_Info info;
	info.add_flags(
		"-macosx_version_min",
		"10.16",
		"-lsystem",
	);
	return info;
}

void link_objs(string[] obj_paths, string out_name) {
	logger.Verbose("Linking...");

	string obj_files;
	foreach (i, obj; obj_paths) {
		if (i > 0) obj_files ~= " ";
		obj_files ~= obj;
	}

	Linker_Info info;
	version (OSX) {
		info = link_objs_osx();
	}
	else version (Posix) {
		info = link_objs_linux();
	}
	info.add_objs(obj_paths);

	auto linker_args = ["/usr/bin/ld"] ~ info.flags ~ info.objects ~ ["-o", out_name];
	writeln("Running linker", linker_args);
	auto ld_pid = execute(linker_args);
	if (ld_pid.status != 0) {
		writeln("Linker failed:\n", ld_pid.output);
	} else {
		writeln("Linker notes:\n", ld_pid.output);
	}
}