import std.stdio;
import std.datetime.stopwatch : StopWatch;
import std.conv;

import kargs.command;
import logger;

bool DONT_COMPILE = false;

void main(string[] args) {
  StopWatch compilerTimer;
  compilerTimer.start();

  process_args(args);

  if (args.length == 1) {
    logger.Error("no input file.");
    return;
  }

  auto duration = compilerTimer.peek();
  logger.Info("Compiler took ", to!string(
      duration.total!"msecs"), "/ms or ", to!string(duration.total!"usecs"), "/µs");
}