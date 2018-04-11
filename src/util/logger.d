module logger;

import std.conv;
import std.stdio;
import std.algorithm.comparison : min, max;
import std.string;
import std.array;
import std.outbuffer;

import cflags;
import tok;
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
	auto line_start_index = cast(uint) lastIndexOf(file.contents, '\n', cast(size_t) index);
	line_start_index = line_start_index == -1 ? 0 : line_start_index;

	auto line_end_index = cast(uint) indexOf(file.contents, '\n', cast(size_t) index);
	line_end_index = line_end_index == -1 ? 0 : line_end_index;
	if (line_end_index < line_start_index) {
		line_end_index = cast(uint) file.contents.length;
	}

	auto slice = file.contents[line_start_index .. line_end_index];
	return strip(slice);
}

static string blame_token_span(Token_Span span) {
	// for now
	return blame_token(span.get_tok());
}

static string blame_token(Token_Info tok_info) {
	if (auto span = cast(Token_Span) tok_info) {
		return blame_token_span(span);
	}
	else if (auto abs = cast(Absolute_Token) tok_info) {
		return blame_token(abs.tok);
	}

	assert(0);
}

static string blame_token(Token tok) {
	if (tok is null) {
		debug {
			assert(0);
		}
		else {
			// little crazy string that looks similar
			// to the error template.
			return "?!|\n  |\t?!\n";
		}
	}

	Source_File file = tok.parent;
	const size_t index = tok.position.start.idx;

	// capture to the previous line
	// of the token.
	long token_start = lastIndexOf(file.contents, '\n', cast(size_t) index);
	token_start = max(0, token_start);

	// size of the before token context
	long prefix_size = index - token_start;

	// capture up to the next newline
	auto line_end_index = indexOf(file.contents, '\n', cast(size_t) index);
	line_end_index = max(0, line_end_index);

	if (line_end_index < token_start) {
		line_end_index = file.contents.length;
	}

	// slice the start context
	auto start = file.contents[token_start .. (token_start + prefix_size)];

	// strip out any padding stuff
	auto old_start_len = start.length;
	start = stripLeft(start);

	long token_end = token_start + prefix_size + tok.lexeme.length;
	auto end = file.contents[token_end .. line_end_index];

	// because we stripped the junk, we have to
	// change the prefix size now for the formatting phase.
	prefix_size -= old_start_len - start.length;

	string underline = replicate(" ", prefix_size) ~ colour.Err(replicate("^", tok.lexeme.length));

	string tab = replicate(" ", TAB_SIZE);
	auto row_str = to!string(tok.position.start.row);

	const auto padding = replicate(" ", cast(size_t) row_str.length);

	auto buff = new OutBuffer();

	// TODO show a line before and after for context
	// rather than the individual line. have a flag
	// option to disable this for when we get a LOT of errors!

	buff.writefln("%s> %s:%d", replicate("-", cast(size_t) row_str.length + 1),
			tok.parent.path, tok.position.start.row);
	buff.writefln("%s| %s", tok.position.start.row,
			tab ~ start ~ colour.Bold(colour.Err(tok.lexeme)) ~ end);
	buff.writefln("%s| %s", padding, tab ~ underline);

	return buff.toString();
}

private uint num_logger_errors = 0;

int get_err_count() {
	return num_logger_errors;
}

static void log(Log_Level lvl, string[] str...) {
	if (lvl == Log_Level.Error) {
		num_logger_errors++;
	}

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
	default:
		break;
	}

	string level_str = to!string(lvl);
	auto error_level = colour.Colourize(col, level_str);

	if (lvl != Log_Level.Verbose) {
		out_stream.writef("%s: ", error_level);
	}

	string result;
	foreach (s; str) {
		result ~= s;
	}
	out_stream.writeln(result);

	if (lvl == Log_Level.Fatal) {
		debug {
			assert(0);
		}
		else {
			import core.stdc.stdlib : exit;
			exit(0);
		}
	}
}

// TODO
static void error(Token_Info t, string msg) {
	error(msg, "\n", blame_token(t));
}

static void error(Token t, string msg) {
	error(msg, "\n", blame_token(t));
}

// TODO remove the lazy join things

static void error(string[] strings...) {
	log(Log_Level.Error, strings);
}

static void warn(string[] strings...) {
	log(Log_Level.Warning, strings);
}

static void info(string[] strings...) {
	log(Log_Level.Info, strings);
}

static void fatal(string[] strings...) {
	log(Log_Level.Fatal, strings);
}

static void verbose(string[] strings...) {
	log(Log_Level.Verbose, strings);
}

// prints a verbose message in a nice big
// obnoxious border.
static void verbose_header(string[] strings...) {
	if (!VERBOSE_LOGGING) {
		return;
	}

	string res;
	foreach (s; strings) {
		res ~= s;
	}
	writeln("! ", colour.Bold(res));
}
