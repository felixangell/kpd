import std.stdio;
import std.array;
import std.algorithm.searching : endsWith;

import krug_module;

const KRUG_EXT = ".krug";

void main(string[] args) {
	auto main_module = Krug_Module(args[1]);
}
