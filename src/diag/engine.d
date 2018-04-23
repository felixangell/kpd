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

	static void throw_error(Compiler_Error err, string[] names, Token[] context...) {
		Token_Info[] ctx;
		ctx.reserve(context.length);

		foreach (ref tok; context) {
			ctx ~= new Absolute_Token(tok);
		}

		throw_error(err, names, ctx);
	}

	static void throw_error(Compiler_Error err, Token_Info[] context...) {
		string[] token_names;

		foreach (idx, tok; context) {
			if (tok is null) {
				token_names ~= "? compiler bug ?";
				continue;
			}
			token_names ~= tok.print_tok();
		}

		throw_error(err, token_names, context);
	}

	// this is a code error as it takes tokens for context and
	// blames them! distinguish this. also it uses a predefined
	// error message template
	static void throw_error(Compiler_Error err, string[] names, Token_Info[] context...) {
		thrown_errors[err] = true;

		string error_msg; // todo buffer thing
		foreach (idx, error; err.errors) {
			string blame = null;
			if (context !is null && context[idx] !is null) {
				blame = blame_token(context[idx]);
			}

			char[1024] buff;
			error_msg ~= sformat(buff[], error, colour.Bold(names[idx]));

			if (blame !is null) {
				error_msg ~= ":\n" ~ blame;
			}
		}
		error_msg ~= '\n';

		char[8] id_buff;
		logger.error(colour.Err("[E" ~ to!string(sformat(id_buff[], "%04d", err.id)) ~ "]:\n") ~ error_msg);
	}
}
