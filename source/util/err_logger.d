module err_logger;

import std.conv;
import std.stdio;
import std.string;
import std.array;
import std.outbuffer;

import cflags;
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
static string Blame_Token(ref Token tok) {
    if (tok is null) {
        return "token is null!";
    }

    const Source_File* file = tok.parent;

    const size_t index = tok.position.start.idx;

    long token_start = lastIndexOf(file.contents, '\n', cast(size_t)index);
    if (token_start == -1) token_start = 0;

    long prefix_size = tok.position.start.idx - token_start;

    auto line_end_index = indexOf(file.contents, '\n', cast(size_t)index);
    if (line_end_index == -1) line_end_index = 0;

    if (line_end_index < token_start) {
        line_end_index = file.contents.length;
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

    const auto padding = replicate(" ", cast(size_t)row_str.length);

    auto buff = new OutBuffer();

    // TODO show a line before and after for context
    // rather than the individual line. have a flag
    // option to disable this for when we get a LOT of errors!

    buff.writefln("%s> %s:%d", replicate("-", cast(size_t)row_str.length + 1), tok.parent.path, tok.position.start.row);
    buff.writefln("%s| %s", tok.position.start.row,
        tab ~ start ~ colour.Bold(colour.Err(tok.lexeme)) ~ end);
    buff.writefln("%s| %s", padding, tab ~ underline);

    return buff.toString();
}

static void Log(Log_Level lvl, string str) {
    if (lvl == Log_Level.Verbose && !VERBOSE_LOGGING) {
        return;
    }

    if (SUPPRESS_COMPILER_WARNINGS && lvl == Log_Level.Warning) {
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
    writeln(Blame_Token(context));
}

static void Error(string[] str) {
    Error(str[0]);
    for (int i = 1; i < str.length; i++) {
        stderr.writeln(str[i]);
    }
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

static void Verbose(string[] strings...) {
    // eh
    string s;
    foreach (str; strings) {
        s ~= str;
    }
	Log(Log_Level.Verbose, s);
}