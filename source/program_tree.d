module program_tree;

import std.stdio;
import std.array;
import std.algorithm.searching : endsWith;
import std.algorithm;
import std.file;
import std.path;
import std.string : lastIndexOf;

import krug_module;
import tokenize;
import load_directive_parser;
import ds;
import err_logger;

// builds a program tree or rather a dependency graph
// of the given program

struct Dependency {
	string path;
	Dependency[] edges;

	this(string path) {
		this.path = path;
	}

	string name() {
		return std.path.baseName(path);
	}
}

alias Dependency_Graph = Dependency[string];

void add_edge(Dependency_Graph graph, string from, Dependency to) {
	if (from !in graph) {
		writeln("apparently " ~ from ~ " is not registered in the dep graph");
		assert(0 && "this should not be happening");
	}

	if (to.name() !in graph) {
		graph.register_dep(to);
	}

	Dependency* dep = &graph[from];
	dep.edges ~= to;
}

void register_dep(Dependency_Graph graph, Dependency dep) {
	graph[dep.name()] = dep;
}

struct Module {
    string path;
    Hash_Set!string fileCache;
    Source_File[string] children;

    this(string path) {
        this.path = path;
        this.fileCache = list_dir(path);
    }

    bool sub_module_exists(string name) {
        // check that the sub-module exists, it's
        // easier to append the krug extension on at this point
        return (name ~ ".krug") in fileCache;
    }

    Source_File load_source_file(string name) {
        const string source_file_path = this.path ~ std.path.dirSeparator ~ name ~ ".krug";
        auto source_file = Source_File(source_file_path);
        children[name] = source_file;
        return source_file;
    }
}

struct Krug_Project {
    // the directory that the project is based in
    string path;

    // just because it's a folder in the project
    // does not mean it's a code module. this array
    // is full of all the LOADED code modules.
    Module[string] modules;

    this(string path) {
        this.path = path;
    }

    Module load_module(string name) {
        if (name in modules) {
            err_logger.Verbose("Module '" ~ name ~ "' already loaded - skipping.");
            return modules[name];
        }

        err_logger.Verbose("Loading module '" ~ name ~ "'.");

        auto mod = Module(this.path ~ std.path.dirSeparator ~ name ~ std.path.dirSeparator);

        foreach (file; mod.fileCache) {
            if (!file.endsWith(".krug")) {
                continue;
            }

            Source_File source_file = mod.load_source_file(std.path.stripExtension(file));
            auto tokens = new Lexer(source_file.contents).tokenize();
            auto deps = collect_deps(tokens);
            foreach (dep; deps) {
                string module_name = dep[0].lexeme;
                load_module(module_name);
            }
        }

        modules[name] = mod;
        return mod;
    }

    bool module_exists(string name) {
        const string mod_path = this.path ~ std.path.dirSeparator ~ name ~ std.path.dirSeparator;
        return std.file.exists(mod_path) && std.file.isDir(mod_path);
    }
}

// TODO: detect circular dependencies
// for now we assume that the input program
// is acyclic but this needs to be resolved
// otherwise if we are given a cyclic program
// then the compiler will likely crash with a nasty error.
void build_program_tree(ref Source_File main_module) {
	err_logger.Verbose("Building program tree `" ~ main_module.path ~ "`");

    /*
        things to ensure/consider/check:
        - module names dont collide with other local modules
        - module names dont collide with standard library modules
        - should we do a lookup locally or against the standard library first?
    */

    {
        auto tokens = new Lexer(main_module.contents).tokenize();
        Load_Directive[] dirs = collect_deps(tokens);

        string main_module_path = buildNormalizedPath(absolutePath(main_module.path));
        auto project = Krug_Project(strip_file(main_module_path));

        foreach (dir; dirs) {
            Token[] sub_modules = dir[1];

            string module_name = dir[0].lexeme;

            if (!project.module_exists(module_name)) {
                err_logger.Error("No such module '" ~ module_name ~ "'.");
                continue;
            }

            Module mod = project.load_module(module_name);
        }
    }

    bool run_code = false;
    if (run_code) {
        // this is the path to the main module, i.e.
        // the file called "main.krug".
        string main_module_path = buildNormalizedPath(absolutePath(main_module.path));

        // the directory of the main project folder, i.e.
        // the parent directory for the main module path
        // so if the main module is `w:/foo/main.krug` then the
        // project path is `w:/foo`.
        string project_abs_path = strip_file(main_module_path);

        Lexer lex_inst = new Lexer(main_module.contents);
        auto tokens = lex_inst.tokenize();

        // all of the dependencies in our program
        Dependency_Graph dep_graph;
        auto main_dep = Dependency(main_module_path);
        dep_graph.register_dep(main_dep);

        Load_Directive[] loads = collect_deps(tokens);
        foreach (load; loads) {
            // name of the module
            string module_name = load[0].lexeme;
            dep_graph.add_edge(main_dep.name(), Dependency(project_abs_path ~ std.path.dirSeparator ~ module_name));
        }
    }
}

// lists file and directories
Hash_Set!string list_dir(string pathname) {
	Hash_Set!string dirs = new Hash_Set!string();
   	foreach (file; std.file.dirEntries(pathname, SpanMode.shallow)) {
		if (file.isFile || file.isDir) {
			dirs.insert(std.path.baseName(file.name));
		}
   	}
   	return dirs;
}

string strip_file(string path) {
	// get the parent folder of the file
	// to do this we look at where the 
	// last index of a file sep char is (/)
	// and then substring from 0 to that index.
	auto idx = lastIndexOf(path, std.path.dirSeparator);
	assert(idx != -1 && "oh shit");
	return path[0..idx];
}