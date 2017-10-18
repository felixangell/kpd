import std.stdio;
import std.array;
import std.algorithm.searching : endsWith;
import std.algorithm;
import std.file;
import std.path;
import std.string : lastIndexOf;

import krug_module;
import tokenize;
import dep_tree;
import parse;
import ds;

const KRUG_EXT = ".krug";

// lists file and directories
Hash_Set!string list_dir(string pathname) {
	Hash_Set!string dirs = new Hash_Set!string();
   	foreach (file; std.file.dirEntries(pathname, SpanMode.shallow)) {
		if (file.isFile || file.isDir) {
			dirs.insert(std.path.baseName(file.name));
		}
   	}
   	return dirs;
}

string strip_file(string path) {
	// get the parent folder of the file
	// to do this we look at where the 
	// last index of a file sep char is (/)
	// and then substring from 0 to that index.
	auto idx = lastIndexOf(path, std.path.dirSeparator);
	assert(idx != -1 && "oh shit");
	return path[0..idx];
}

void scan_module(Krug_Module mod_name) {
	
}

void main(string[] args) {
	auto main_module = Krug_Module(args[1]);

	// lex the main module only, then
	// we run it through the dep tree analyzer thing
	Lexer lex_inst = new Lexer(main_module.contents);
	auto tokens = lex_inst.tokenize();

	 // the path has to be noramlized because
	// dlang stdlib only handles forward slashes
	// whereas windows allows a backwards slash in
	// a path
	string abs = buildNormalizedPath(absolutePath(args[1]));
	string parent_dir = strip_file(abs);	

	// list the directories in the parent directory
	Hash_Set!string root_dir = list_dir(parent_dir);

	// parse the _main_ dependency first	
	Dependency[] deps = parse_dep_tree(tokens);

	uint num_fails = 0;

	foreach (dep; deps) {
		auto module_name = dep.module_name.lexeme;
		if (module_name !in root_dir) {
			writeln("Could not find module " ~ module_name);
			continue;
		}

		// make sure sub modules exist too
		foreach (sub_mod; dep.sub_mods) {
			auto sub_mod_name = sub_mod.lexeme;
			string sub_mod_path = parent_dir 
					~ std.path.dirSeparator
					~ module_name 
					~ std.path.dirSeparator
					~ sub_mod_name 
					~ ".krug";
					
			if (!exists(sub_mod_path)) {
				writeln("no such module: " ~ sub_mod_path);
				num_fails++;
			}
		}
	}
}