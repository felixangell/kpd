import std.stdio;
import std.conv;

import kargs.command;
import logger;

void main(string[] args) {
	if (args.length == 1) {
		logger.Fatal("No sub-command offered.");
		return;
	}

	string command_name = args[1];
	if (command_name in commands) {
		commands[command_name].process(args[2 .. $]);
	}
	else if (command_name.length == 1 && command_name[0] in short_flags) {
		string cmd_name = short_flags[command_name[0]];
		commands[cmd_name].process(args[2 .. $]);
	}
	else {
		logger.Fatal("No such command '", command_name, "'.");
	}
}
