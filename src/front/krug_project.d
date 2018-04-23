module krug_project;

import std.stdio;
import std.conv;
import std.algorithm.comparison : equal;
import std.typecons;
import std.range.primitives;

import diag.engine;
import compiler_error;
import keyword;
import lex.lexer;
import ast;
import tok : Token, Token_Type;
import krug_module;
import logger;
import dep_graph;

struct Krug_Project {
	// the directory that the project is based in
	string path;

	Module[string] modules;
	
	Dependency_Graph graph;

	this(string path) {
		this.path = path;
	}
}

private struct Krug_Module_Info {
	// the name of this module
	// declared with the 
	// module directive
	string name;

	// paths of this modules
	// dependencies.
	string[] dependencies;
}

// retrieves the module name from
// the given token stream. returns the first
// module directive we encounter.
string parse_module_name(Token[] tokens) {
	auto parser = Token_Parser(tokens);
	while (parser.has_next()) {
		auto curr = parser.consume();
		if (!curr.cmp(keyword.Directive_Symbol)) {
			continue;
		}

		auto dir_type = parser.consume();
		switch (dir_type.lexeme) {
		case keyword.Module_Directive:
			return parser.expect(Token_Type.Identifier).lexeme;
		default:
			// skip any other directive.
			continue;
		}
	}

	// TODO handle this error properly.
	assert(0, "no module name found for token stream given");
}

// parses all of the krug files that this
// module depends on.
//
// for example could return
// { foo/bar.krug,
// foo/blah/baz.krug,
// bar/bar.krug }
Krug_Module_Info parse_dependencies(Token[] tokens) {
	string[] filepath_dependencies;
	string name = null;

	auto parser = Token_Parser(tokens);
	while (parser.has_next()) {
		auto curr = parser.consume();
		if (!curr.cmp(keyword.Directive_Symbol)) {
			continue;
		}

		auto dir_type = parser.consume();
		switch (dir_type.lexeme) {
		case keyword.Module_Directive:
			// set the name of this module
			// accordingly. 
			// TODO: handle 
			// #module gfx.window
			// TODO: handle errors.
			name = parser.expect(Token_Type.Identifier).lexeme;
			continue;
		case keyword.Load_Directive:
			// fall down to the code below
			break;
		default:
			// skip any other directive.
			continue;
		}

		// at this point we should have something
		// like this:
		// #load 

		auto path = parser.expect(Token_Type.String);
		filepath_dependencies ~= path.lexeme[1..$-1]; // strip the quotes.
	}

	return Krug_Module_Info(name, filepath_dependencies);
}

// this will build a krug project
// from the given main entry source file
//
// this works by lazily parsing the source file
// and building a dependency graph of the program.
//
// TODO do the depedency graph tarjans stuff here and
// dont expose the api to the rest of the compiler
Krug_Project build_krug_project(ref Source_File main_source_file) {
	logger.verbose("Building program tree `" ~ main_source_file.path ~ "`");

	Krug_Project proj;

	bool[string] visited_files;
	Source_File[] process;
	process ~= main_source_file;

	// source file paths -> parent modules
	string[string] edges;

	while (process.length > 0) {
		auto file = process.back();

		visited_files[file.path] = true;
		auto tokens = new Lexer(file).tokenize();
		process.popBack();

		Krug_Module_Info minfo = parse_dependencies(tokens);
		if (minfo.name is null) {
			// TODO pass in a more relevant token? or rather
			// alow the diagnostic engine to just take strings
			// as well as tokens.
			Diagnostic_Engine.throw_error(NO_MOD_NAME, [main_source_file.path], tokens[0]);
			break;
		}

		Module mod = null;
		if (minfo.name in proj.modules) {
			mod = proj.modules[minfo.name];
		}
		else {
			mod = new Module(minfo.name);
			proj.graph.register_module(mod);
			proj.modules[minfo.name] = mod;
		}
	
		writeln("- registered file ", file.path, " childof ", mod.name);
		mod.source_files[file.path] = file;
		mod.token_streams[file.path] = tokens;

		// the only time this condition should
		// not evaluate is when we process the first
		// main module which has no dependencies.
		// add an edge from the file -> mod
		if (file.path in edges) {
			proj.graph.add_dependency(edges[file.path], mod);
		}

		foreach (ref dep; minfo.dependencies) {
			if (dep in visited_files) {
				continue;
			}
			auto sfile = new Source_File(dep);
			process ~= sfile;
			edges[sfile.path] = minfo.name;
		}
	}

	return proj;
}

struct Token_Parser {
	Token[] toks;
	uint pos;

	this(ref Token[] toks) {
		this.toks = toks;
		this.pos = 0;
	}

	Token consume() {
		return toks[pos++];
	}

	Token expect(string lexeme) {
		Token t = peek();
		if (t.lexeme.equal(lexeme)) {
			return consume();
		}

		writeln("oh dear! " ~ lexeme ~ " vs. `" ~ t.lexeme ~ "` for " ~ to!string(t));
		return null;
	}

	Token expect(Token_Type type) {
		Token t = consume();
		if (t.type == type) {
			return t;
		}

		writeln("oh dear, type mismatch! " ~ to!string(type) ~ " vs " ~ to!string(t.type) ~ " for " ~ to!string(t));
		assert(0);
	}

	bool has_next() {
		return pos < toks.length;
	}

	Token peek(int offs = 0) {
		return toks[pos + offs];
	}
}
