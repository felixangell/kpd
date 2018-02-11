module diag.engine;

import std.format;

import err_logger;
import krug_module : Token;
import diag.error;
import colour;

char[] sformat_expand(Args...)(char[] buf, string format, Args args) {
    return sformat(buf, format, args);
}

struct Diagnostic_Engine {
	static bool[Compiler_Error] thrown_errors; 

	static void throw_error(Compiler_Error err, Token[] context ...) {
		thrown_errors[err] = true;

		string[] token_names;
		token_names.length = context.length;

		foreach (idx, tok; context) {
			token_names ~= colour.Bold(tok.lexeme);
		}

		string error_msg; // todo buffer thing
		foreach (idx, error; err.errors) {
			char[1024] buff;
			error_msg ~= sformat_expand(buff[], error, token_names);
			error_msg ~= '\n';
			error_msg ~= Blame_Token(context[idx]);
		}

		err_logger.Error(colour.Err("error[E0000]:\n") ~ error_msg);
	}
}