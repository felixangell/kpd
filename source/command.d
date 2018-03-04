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

Command[string] commands;
string[char] short_flags;

static this() {
	register_command(new Build_Command());
	register_command(new Explain_Command());
	register_command(new Run_Command());
}

void register_command(Command c) {
	commands[c.name] = c;
	short_flags[c.shortcut] = c.name;
}