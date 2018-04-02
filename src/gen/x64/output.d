module gen.x64.output;

import std.stdio;
import std.conv;
import std.array : replicate;

import logger;
import gen.backend;
import kt;
import kir.instr;

import gen.x64.formatter;

enum TAB_SIZE = 4;

class X64_Code : Generated_Output {
	string[] _assembly_code;
	uint index = 0;

	this() {
		_assembly_code = [];

		// fixme arbitrary value
		_assembly_code.length += 32;
	}


	string assembly_code() {
		string res;
		foreach (line; _assembly_code[0..index]) {
			res ~= line ~ '\n';
		}
		return res;
	}

	private void resize() {
		if (index >= _assembly_code.length) {
			_assembly_code.length *= 2;
		}
	}

	uint emit(string fmt, string[] s...) {
		resize();
		uint emit_addr = index++;
		_assembly_code[emit_addr] = sfmt(fmt, s);
		return emit_addr;
	}

	void emitt_at(uint index, string fmt, string[] s...) {
		resize();
		_assembly_code[index] = replicate(" ", TAB_SIZE) ~ sfmt(fmt, s);
	}

	uint emitt(string fmt, string[] s...) {
		resize();
		uint emit_addr = index++;
		emitt_at(emit_addr, fmt, s);
		return emit_addr;
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