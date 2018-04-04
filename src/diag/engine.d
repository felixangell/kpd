module diag.engine;

import std.stdio;
import std.format;
import std.conv;

import std.algorithm.searching : countUntil;

import logger;
import tok;
import compiler_error;
import colour;

// this is messy, fixme!

struct Diagnostic_Engine {
	static bool[Compiler_Error] thrown_errors;

	// this is an error with a custom error message
	static void throw_custom_error(Compiler_Error err, string msg) {
		char[8] id_buff;
		auto err_code_str = to!string(sformat(id_buff[], "%04d", err.id));

		logger.error(colour.Err("[E" ~ err_code_str ~ "]:\n") ~ msg ~
				"\n\n./krug --explain E" ~ err_code_str ~ " to explain the error.");
	}

	// this is a code error as it takes tokens for context and
	// blames them! distinguish this. also it uses a predefined
	// error message template
	static void throw_error(Compiler_Error err, Token_Info[] context...) {
		thrown_errors[err] = true;

		string[] token_names;

		foreach (idx, tok; context) {
			if (tok is null) {
				token_names ~= "?";
				continue;
			}
			token_names ~= colour.Bold(tok.get_tok().lexeme);
		}

		string error_msg; // todo buffer thing
		foreach (idx, error; err.errors) {
			char[1024] buff;
			error_msg ~= sformat(buff[], error, token_names[idx]);
			error_msg ~= '\n';

			// TODO make this use the token_info range
			error_msg ~= blame_token(context[idx].get_tok());
		}

		char[8] id_buff;
		logger.error(colour.Err("[E" ~ to!string(sformat(id_buff[], "%04d",
				err.id)) ~ "]:\n") ~ error_msg);
	}
}
