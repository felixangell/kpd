module kargs.command;

import kargs.run;
import kargs.explain;
import kargs.build;
import logger;

class Command {
	string name;
	char shortcut; // typicaly name[0]

	this(string name) {
		this.name = name;
		this.shortcut = name[0];
	}

	abstract void process(string[] args);
}

private Command[string] commands;
private string[char] short_flags;

static this() {
	register_command(new Build_Command());
	register_command(new Explain_Command());
	register_command(new Run_Command());
}

void register_command(Command c) {
	commands[c.name] = c;
	short_flags[c.shortcut] = c.name;
}

void process_args(string[] args) {
	if (args.length == 1) {
		logger.Fatal("No sub-command offered.");
		return;
	}

	string command_name = args[1];
	if (command_name in commands) {
		commands[command_name].process(args[2..$]);
	}
	else if (command_name.length == 1 && command_name[0] in short_flags) {
		string cmd_name = short_flags[command_name[0]];
		commands[cmd_name].process(args[2..$]);
	}
	else {
		logger.Fatal("No such command '", command_name, "'.");
	}
}