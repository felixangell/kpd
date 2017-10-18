module err_logger;

import std.stdio;

enum Log_Level {
	Fatal,
	Verbose,
	Error,
	Warning,
}

static void Log(Log_Level lvl, string str) {
	auto out_stream = (lvl == Log_Level.Error || lvl == Log_Level.Fatal) ? stderr : stdout;
	out_stream.writef(str);
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