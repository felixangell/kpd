module gen.x64.output;

import std.conv;

import gen.backend;

class X64_Code : Generated_Output {
	string assembly_code;

	this() {
		assembly_code = "";
	}

	this(string assembly_code) {
		this.assembly_code = assembly_code;
	}

	void emit(string fmt, string[] s...) {
		assembly_code ~= sfmt(fmt, s) ~ '\n';
	}

	void emitt(string fmt, string[] s...) {
		assembly_code ~= '\t' ~ sfmt(fmt, s) ~ '\n';
	}

	void push(int width, string[] p...) {
		string instr_width;
		final switch (width) {
		case 32: 
			instr_width = "l";
			break;
		case 64: 
			instr_width = "q";
			break;
		}

		emit("{}", sfmt("push{}", instr_width));
		emit("{}", p);
	}
}

// really shitty sprintf type thing
// that isnt really type safe and doesnt
// handle a lot of edge cases if any!
string sfmt(string fmt, string[] s...) {
	string output;
	wchar[] format = to!(wchar[])(fmt);
	int repl_count = 0;
	for (int i = 0; i < format.length; i++) {
		if (format[i] == '{' && format[i + 1] == '}') {
			output ~= s[repl_count++];
			i++;
			continue;
		}
		output ~= format[i];
	}
	return output;
}