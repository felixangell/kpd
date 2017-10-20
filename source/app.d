import std.stdio;

import program_tree;
import krug_module;
import parse.parser;

const KRUG_EXT = ".krug";

void main(string[] args) {
	auto main_module = Krug_Module(args[1]);
	build_program_tree(main_module);
}