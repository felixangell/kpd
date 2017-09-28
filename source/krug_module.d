module krug_module;

import std.file;

struct Token {
	string name;
	enum Token_Type {
		Identifier,
		Floating_Number,
		Whole_Number,
		String,
		Rune,
	};
}

struct Krug_Module {
	string name;
	string path;
	string contents;

	this(string path) {
		this.path = path;
		this.contents = readText(path);
	}
}