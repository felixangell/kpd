module err_logger;

import std.conv;
import std.stdio;
import std.string;
import std.array;

import krug_module;
import colour;

const uint TAB_SIZE = 4;

enum Log_Level {
	Fatal,
	Verbose,
	Error,
	Warning,
}

static string get_line(const(Source_File*) file, ulong index) {
    auto line_start_index = cast(uint) lastIndexOf(file.contents, '\n', cast(size_t)index);
    line_start_index = line_start_index == -1 ? 0 : line_start_index;

    auto line_end_index = cast(uint) indexOf(file.contents, '\n', cast(size_t)index);
    line_end_index = line_end_index == -1 ? 0 : line_end_index;
    if (line_end_index < line_start_index) {
        line_end_index = cast(uint) file.contents.length;
    }

    auto slice = file.contents[line_start_index .. line_end_index];
    return strip(slice);
}

static void Blame_Token(ref Token tok) {
    const Source_File* file = tok.parent;

    const uint index = tok.position.start.idx;

    uint token_start = cast(uint) lastIndexOf(file.contents, '\n', cast(size_t)index) + 2;
    const uint prefix_size = tok.position.start.idx - token_start;

    auto line_end_index = cast(uint) indexOf(file.contents, '\n', cast(size_t)index);
    line_end_index = line_end_index == -1 ? 0 : line_end_index;
    if (line_end_index < token_start) {
        line_end_index = cast(uint) file.contents.length;
    }

    auto start = file.contents[token_start .. token_start + prefix_size];
    auto end = file.contents[token_start + prefix_size + tok.lexeme.length .. line_end_index];

    string underline = replicate(" ", prefix_size)
        ~ colour.Err(replicate("^", tok.lexeme.length));

    string tab = replicate(" ", TAB_SIZE);
    auto row_str = to!string(tok.position.start.row);

    writefln("%s|>%s", tok.position.start.row,
        tab ~ start ~ colour.Bold(colour.Warn(tok.lexeme)) ~ end);

    const auto padding = replicate(" ", cast(size_t)row_str.length);
    writefln("%s >%s", padding, tab ~ underline);
}

static void Log(Log_Level lvl, string str) {
	auto out_stream = (lvl == Log_Level.Error || lvl == Log_Level.Fatal) ? stderr : stdout;
	import std.uni : toLower;
	auto error_level = toLower(to!string(lvl));
	out_stream.writeln(error_level ~ ": " ~ str);
}

static void Error(string str) {
	Log(Log_Level.Error, str);
}

static void Warn(string str) {
	Log(Log_Level.Warning, str);
}

static void Fatal(string str) {
	Log(Log_Level.Fatal, str);
	assert(0); // TODO:
}

static void Verbose(string str) {
	Log(Log_Level.Verbose, str);
}