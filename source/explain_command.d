module kargs.explain;

import std.stdio;
import std.conv;

import compiler_error;
import logger;
import kargs.command;

void explain_err(string err_code) {
  // validate the error code first:
  if (err_code.length != 5) {
    logger.Error("Invalid error code '", err_code, "' - error code format is EXXXX");
    return;
  }

  auto num = to!ushort(err_code[1 .. $]);
  if (num < 0) {
    logger.Error("Invalid error code sign '", err_code, "'");
    return;
  }

  if (num in compiler_error.ERROR_REGISTER) {
    auto error = compiler_error.ERROR_REGISTER[num];
    writeln(error.detail);
  } 
  else {
    logger.Error("No such error defined for '", err_code, "'");
  }
}

class Explain_Command : Command {
	this() { 
		super("explain"); 
	}

	override void process(string[] args) {
		if (args.length == 0) {
			logger.Fatal("Expected error code in the format of EXXXX.");
			return;
		}

		explain_err(args[0]);
	}
}