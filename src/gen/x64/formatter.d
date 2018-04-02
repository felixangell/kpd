module gen.x64.formatter;

import std.conv : to;

// sfmt is a string formatting utility thing
// it's incredibly simple and is not type safe
// etc...
// the first argument, fmt, is the string to format
// placeholders are specified with curly braces {}
// the second argument s, are replacements which are
// replaced with the placeholders _in order_
// for example
//
// sfmt("hello {} how are you", some_name_var);
// will give us
// hello John how are you
string sfmt(string fmt, string[] s...) {
	string output;
	wchar[] format = to!(wchar[])(fmt);
	int repl_count = 0;
	for (int i = 0; i < format.length; i++) {
		if (format[i] == '{' && format[i + 1] == '}') {
			output ~= s[repl_count++];
			i++;
			continue;
		}
		output ~= format[i];
	}
	return output;
}

unittest {
	assert(sfmt("hello {} how are you", "felix") == "hello felix how are you");
}