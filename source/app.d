import std.stdio;
import std.array;
import std.algorithm.searching : endsWith;
import std.algorithm;
import std.file;
import std.path;

import krug_module;
import tokenize;
import dep_tree;

const KRUG_EXT = ".krug";

// lists file and directories
string[] list_dir(string pathname) {
    return std.file.dirEntries(pathname, SpanMode.shallow)
        .filter!(a => a.isFile || a.isDir)
        .map!(a => std.path.baseName(a.name))
        .array;
}

// TODO: there must be a way to do this in the
// standard library properly!
string strip_file(string path) {
	// get the parent folder of the file
	// to do this we look at where the 
	// last index of a file sep char is (/)
	// and then substring from 0 to that index.
	
	writeln("getting parent dir for " ~ path);

	int idx = -1;
	for (int i = path.length - 1; i > 0; i--) {
		import std.conv : to;
		import std.algorithm : cmp;

		if (!to!string(path[i]).cmp(std.path.dirSeparator)) {
			idx = i;
			break;
		}
	}

	assert(idx != -1 && "oh shit");
	return path[0..idx];
}

void main(string[] args) {
	auto main_module = Krug_Module(args[1]);

	// lex the main module only, then
	// we run it through the dep tree analyzer thing
	Lexer lex_inst = new Lexer(main_module.contents);
	auto tokens = lex_inst.tokenize();
	foreach (token; tokens) {
		writeln(token);
	}

	// TODO: we could maybe optimise this by
	// doing a "partial lex" or maybe streaming
	// the file and only lexing the directive
	// tokens, i.e.
	// #load, etc.
	// this way we only load some of the file
	// in and can map out the entire project 
	// module beforehand?

	string abs = buildNormalizedPath(absolutePath(args[1]));
	string parent_dir = strip_file(abs);	
	writeln(list_dir(parent_dir));

	writeln("\nDependencies!\n");
	Dependency[] deps = parse_dep_tree(tokens);
	foreach (dep; deps) {
		writeln(dep);
	}
}
