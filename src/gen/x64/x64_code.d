module gen.x64.output;

import std.stdio;
import std.conv;
import std.array : replicate;

import logger;
import gen.backend;
import kir.instr;

import gen.x64.formatter;

enum TAB_SIZE = 4;

struct Segment_Data {
	string name;
	string[] data;

	// index is one because
	// we write the name of the
	// section in the data in the ctor.
	uint index = 1;

	this(string name) {
		this.data = ["." ~ name];
		this.data.length += 32;
	}

	void resize() {
		if (index >= data.length) {
			data.length *= 2;
		}
	}
}

enum Segment : uint {
	Data,
	Text,
}

class X64_Code : Generated_Output {
	Segment_Data[] segments;
	Segment_Data* current_seg;

	this() {
		segments ~= Segment_Data("data");
		segments ~= Segment_Data("text");
		current_seg = &segments[Segment.Text];
	}

	void set_segment(Segment s) {
		current_seg = &segments[s];
	}

	string assembly_code() {
		string res;
		foreach (seg; segments) {
			foreach (line; seg.data[0..seg.index]) {
				res ~= line ~ '\n';
			}
		}
		return res;
	}

	void dump_to_stdout() {
		import std.string : splitLines;
		foreach (i, line; splitLines(assembly_code)) {
			// we add one because we dont have
			// the newline at the end of the file
			// so we have to offset the line numbers.
			writefln("%04d:\t%s", i + 1, line);
		}
	}

	void emit_data(string fmt, string[] s...) {
		Segment_Data* seg = &segments[Segment.Data];
		seg.resize();
		seg.index++;
		seg.data[seg.index] = sfmt(fmt, s);
	}

	uint emit(string fmt, string[] s...) {
		current_seg.resize();
		uint emit_addr = current_seg.index++;
		current_seg.data[emit_addr] = sfmt(fmt, s);
		return emit_addr;
	}

	void emitt_at(uint index, string fmt, string[] s...) {
		current_seg.resize();
		current_seg.data[index] = replicate(" ", TAB_SIZE) ~ sfmt(fmt, s);
	}

	uint emitt(string fmt, string[] s...) {
		current_seg.resize();
		uint emit_addr = current_seg.index++;
		emitt_at(emit_addr, fmt, s);
		return emit_addr;
	}
}