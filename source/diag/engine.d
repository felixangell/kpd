module diag.engine;

import std.stdio;
import std.format;
import std.conv;

import std.algorithm.searching : countUntil;

import err_logger;
import krug_module : Token;
import diag.error;
import colour;

struct Diagnostic_Engine {
	static bool[Compiler_Error] thrown_errors; 

	static void throw_error(Compiler_Error err, Token[] context ...) {
		thrown_errors[err] = true;

		string[] token_names;

		foreach (idx, tok; context) {
			token_names ~= colour.Bold(tok.lexeme);
		}

		string error_msg; // todo buffer thing
		foreach (idx, error; err.errors) {
			char[1024] buff;
			error_msg ~= sformat(buff[], error, token_names[idx]);
			error_msg ~= '\n';
			error_msg ~= Blame_Token(context[idx]);
		}

		char[8] id_buff;
		auto enum_type_name = to!string(cast(Error_Set)(err));
		ushort id = cast(ushort)([__traits(allMembers, Error_Set)].countUntil(enum_type_name));
		err_logger.Error(colour.Err("error[E" ~ to!string(sformat(id_buff[], "%04d", id)) ~ "]:\n") ~ error_msg);
	}
}