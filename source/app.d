import std.stdio;
import std.array;
import std.algorithm.searching : endsWith;

import krug_module;
import tokenize;
import dep_tree;

const KRUG_EXT = ".krug";

void main(string[] args) {
	auto main_module = Krug_Module(args[1]);

	// lex the main module only, then
	// we run it through the dep tree analyzer thing
	Lexer lex_inst = new Lexer(main_module.contents);
	auto tokens = lex_inst.tokenize();
	foreach (token; tokens) {
		writeln(token);
	}
	parse_dep_tree(tokens);
}
