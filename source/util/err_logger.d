module err_logger;

import std.conv;
import std.stdio;
import std.string;
import std.array;

import krug_module;
import colour;

const uint TAB_SIZE = 4;

bool VERBOSE_LOGGING = false;

enum Log_Level {
	Fatal,
	Verbose,
	Error,
	Warning,
	Info,
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

// FIXME
// this code is very spaghetti but it works.
static void Blame_Token(ref Token tok, File out_stream = stdout) {
    const Source_File* file = tok.parent;

    const uint index = tok.position.start.idx;

    uint token_start = cast(uint) lastIndexOf(file.contents, '\n', cast(size_t)index);
    uint prefix_size = tok.position.start.idx - token_start;

    auto line_end_index = cast(uint) indexOf(file.contents, '\n', cast(size_t)index);
    line_end_index = line_end_index == -1 ? 0 : line_end_index;
    if (line_end_index < token_start) {
        line_end_index = cast(uint) file.contents.length;
    }

    auto start = file.contents[token_start .. token_start + prefix_size];
    auto old_start_len = start.length;
    start = stripLeft(start);
    auto end = file.contents[token_start + prefix_size + tok.lexeme.length .. line_end_index];

    // because we stripped the junk, we have to
    // change the prefix size now for the formatting phase.
    prefix_size -= old_start_len - start.length;

    string underline = replicate(" ", prefix_size)
        ~ colour.Err(replicate("^", tok.lexeme.length));

    string tab = replicate(" ", TAB_SIZE);
    auto row_str = to!string(tok.position.start.row);

    out_stream.writefln("%s|>%s", tok.position.start.row,
        tab ~ start ~ colour.Bold(colour.Err(tok.lexeme)) ~ end);

    const auto padding = replicate(" ", cast(size_t)row_str.length);
    out_stream.writefln("%s >%s", padding, tab ~ underline);
}

static void Log(Log_Level lvl, string str) {
    if (lvl == Log_Level.Verbose && !VERBOSE_LOGGING) {
        return;
    }

	auto out_stream = (lvl == Log_Level.Error || lvl == Log_Level.Fatal) ? stderr : stdout;

    auto col = colour.RESET;
    switch (lvl) {
    case Log_Level.Error:
    case Log_Level.Fatal:
        col = colour.RED;
        break;
    case Log_Level.Verbose:
        col = colour.MAGENTA;
        break;
    case Log_Level.Warning:
        col = colour.YELLOW;
        break;
    default: break;
    }

	import std.uni : toLower;
	auto error_level = colour.Colourize(col, toLower(to!string(lvl)));

	if (lvl == Log_Level.Verbose) {
	    out_stream.writef("# ");
	} else {
       out_stream.writef("%s: ", error_level);
	}
	out_stream.writeln(str);
}

static void Error(Token context, string message) {
    Error(message);
    Blame_Token(context, stderr);
}

static void Error(string str) {
	Log(Log_Level.Error, str);
}

static void Warn(string str) {
	Log(Log_Level.Warning, str);
}

static void Info(string str) {
    Log(Log_Level.Info, str);
}

static void Fatal(string str) {
	Log(Log_Level.Fatal, str);
	assert(0); // TODO:
}

static void Verbose(string str = "") {
	Log(Log_Level.Verbose, str);
}