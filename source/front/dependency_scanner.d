module dependency_scanner;

import std.stdio;
import std.array;
import std.algorithm.searching : endsWith;
import std.algorithm;
import std.file;
import std.path;
import std.string : lastIndexOf;

import containers.hashset;
import lex.lexer;
import parse.load_directive_parser;
import ast;

import krug_module;
import logger;

alias Dependency_Graph = Module[string];

void dump(ref Dependency_Graph graph) {
	writeln("Program dependency graph: ");
	writeln("Dependency name\t\t\t Dependencies: ");
	foreach (mod; graph) {
		write(" - " ~ mod.name);

		if (mod.edges.length > 0) {
			int idx = 0;
			foreach (dep; mod.edges) {
				// TODO: print out a nice table rather
				// at the moment the tabs are trial/errored and
				// will definitely not work in all cases.
				// maybe word wrap the dependencies column nicely because
				// modules will have more than a few dependencies
				// which is all we account for here.
				if (idx == 0)
					write("\t\t\t\t\t ");
				if (idx++ > 0)
					write(", ");
				write(dep.name);
			}
		}
		writeln();
	}
}

void add_edge(ref Dependency_Graph graph, string from, Module to) {
	assert(from in graph);

	if (to.name !in graph) {
		graph.register_module(to);
	}

	Module* mod = &graph[from];
	if (to.name !in mod.edges) {
		mod.edges[to.name] = to;
	}
}

void register_module(ref Dependency_Graph graph, Module mod) {
	graph[mod.name] = mod;
}

struct Krug_Project {
	// the directory that the project is based in
	string path;

	// just because it's a folder in the project
	// does not mean it's a code module. this array
	// is full of all the LOADED code modules.
	Module[string] modules;
	Dependency_Graph graph;

	this(string path) {
		this.path = path;
	}

	Module load_module(string name) {
		if (name in modules) {
			logger.Verbose("Module '" ~ name ~ "' already loaded - skipping.");
			return modules[name];
		}
		logger.Verbose("Loading module '" ~ name ~ "'.");

		auto mod = new Module(this.path ~ std.path.dirSeparator ~ name ~ std.path.dirSeparator);
		modules[name] = mod;

		graph.register_module(mod);

		foreach (ref file; mod.file_cache) {
			if (!file.endsWith(".krug")) {
				continue;
			}

			const string submodule_name = std.path.stripExtension(file);

			Source_File source_file = mod.load_source_file(submodule_name);
			auto tokens = source_file.contents.length == 0 ? [] : new Lexer(source_file)
				.tokenize();
			mod.token_streams[submodule_name] = tokens;

			auto deps = collect_deps(tokens);
			foreach (ref dep; deps) {
				string module_name = dep[0].lexeme;
				Module loaded_module = load_module(module_name);
				graph.add_edge(name, loaded_module);
			}
		}

		return mod;
	}

	bool module_exists(string name) {
		const string mod_path = this.path ~ std.path.dirSeparator ~ name ~ std
			.path.dirSeparator;
		return std.file.exists(mod_path) && std.file.isDir(mod_path);
	}
}

// TODO: detect circular dependencies
// for now we assume that the input program
// is acyclic but this needs to be resolved
// otherwise if we are given a cyclic program
// then the compiler will likely crash with a nasty error.
Krug_Project build_krug_project(ref Source_File main_source_file) {
	logger.Verbose("Building program tree `" ~ main_source_file.path ~ "`");

	auto tokens = new Lexer(main_source_file).tokenize();
	Load_Directive[] dirs = collect_deps(tokens);

	string main_module_path = buildNormalizedPath(absolutePath(main_source_file.path));

	auto file_path = strip_file(main_module_path);
	auto project = Krug_Project(file_path);

	auto main_mod = new Module(file_path);
	project.graph.register_module(main_mod);

	// TODO: this is kind of messy
	main_mod.token_streams[main_mod.name] = tokens;

	foreach (dir; dirs) {
		Token[] sub_modules = dir[1];

		string module_name = dir[0].lexeme;

		if (!project.module_exists(module_name)) {
			// TODO: better error message.
			logger.Error(dir[0], "No such module '" ~ module_name ~ "'.");
			continue;
		}

		Module loaded_module = project.load_module(module_name);
		project.graph.add_edge(main_mod.name, loaded_module);
	}

	return project;
}

string strip_file(string path) {
	// get the parent folder of the file
	// to do this we look at where the 
	// last index of a file sep char is (/)
	// and then substring from 0 to that index.
	auto idx = lastIndexOf(path, std.path.dirSeparator);
	assert(idx != -1 && "oh shit");
	return path[0 .. idx];
}
