module dep_graph;

import std.stdio;
import std.array;
import std.algorithm.searching : endsWith;
import std.algorithm;
import std.file;
import std.path;
import std.string : lastIndexOf;

import lex.lexer;
import parse.load_directive_parser;
import ast;
import tok : Token;
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

void add_dependency(ref Dependency_Graph graph, string from, Module to) {
	assert(from in graph);

	if (to.name !in graph) {
		graph.register_module(to);
	}

	Module* mod = &graph[from];
	if (to.name !in mod.edges) {
		mod.edges[to.name] = to;
	}

	writeln(mod.name, " deps on ", to.name);
}

void register_module(ref Dependency_Graph graph, Module mod) {
	graph[mod.name] = mod;
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
