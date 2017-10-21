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
import ast;

alias Dependency_Graph = Module[string];

void dump(ref Dependency_Graph graph) {
    writeln("Program dependency graph: ");
    writeln("Dependency name\t\t\t Dependencies: ");
    foreach (mod; graph) {
        write(" - " ~ mod.name);

        if (mod.edges.length > 0) {
            int idx = 0;
            foreach (dep; mod.edges) {
                // TODO: print out a nice table rather
                // at the moment the tabs are trial/errored and
                // will definitely not work in all cases.
                // maybe word wrap the dependencies column nicely because
                // modules will have more than a few dependencies
                // which is all we account for here.
                if (idx == 0) write("\t\t\t\t\t ");
                if (idx++ > 0) write(", ");
                write(dep.name);
            }
        }
        writeln();
    }
}

void add_edge(ref Dependency_Graph graph, string from, Module to) {
    assert(from in graph);

    if (to.name !in graph) {
        graph.register_module(to);
    }

    Module* mod = &graph[from];
    if (to.name !in mod.edges) {
        mod.edges[to.name] = to;
    }
}

void register_module(ref Dependency_Graph graph, Module mod) {
	graph[mod.name] = mod;
}

alias Token_Stream = Token[];
alias AST = ast.Node[];

class Module {
    string path, name;
    Hash_Set!string fileCache;

    Source_File[string] source_files;
    Token_Stream[string] token_streams;
    AST[string] as_trees;

    Module[string] edges;

    this() {
        this.path = "";
        this.name = "main";
    }

    this(string path) {
        this.path = path;
        this.name = std.path.baseName(path);
        this.fileCache = list_dir(path);
    }

    size_t dep_count() {
        size_t num_deps = 0;
        foreach (edge; edges) {
            num_deps += edge.dep_count();
        }
        return num_deps + edges.length;
    }

    bool sub_module_exists(string name) {
        assert(name.cmp("main") && "can't check for sub-modules in main module");

        // check that the sub-module exists, it's
        // easier to append the krug extension on at this point
        return (name ~ ".krug") in fileCache;
    }

    Source_File load_source_file(string name) {
        assert(name.cmp("main") && "can't load sub-modules in main module");

        const string source_file_path = this.path ~ std.path.dirSeparator ~ name ~ ".krug";
        auto source_file = new Source_File(source_file_path);
        source_files[name] = source_file;
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
    Dependency_Graph graph;

    this(string path) {
        this.path = path;
    }

    Module load_module(string name) {
        if (name in modules) {
            err_logger.Verbose("Module '" ~ name ~ "' already loaded - skipping.");
            return modules[name];
        }

        err_logger.Verbose("Loading module '" ~ name ~ "'.");

        auto mod = new Module(this.path ~ std.path.dirSeparator ~ name ~ std.path.dirSeparator);
        graph.register_module(mod);

        foreach (file; mod.fileCache) {
            if (!file.endsWith(".krug")) {
                continue;
            }

            const string submodule_name = std.path.stripExtension(file);

            Source_File source_file = mod.load_source_file(submodule_name);
            auto tokens = new Lexer(source_file.contents).tokenize();
            mod.token_streams[submodule_name] = tokens;

            auto deps = collect_deps(tokens);
            foreach (ref dep; deps) {
                string module_name = dep[0].lexeme;
                Module loaded_module = load_module(module_name);
                graph.add_edge(name, loaded_module);
            }
        }

        modules[name] = mod;
        return mod;
    }

    bool module_exists(string name) {
        const string mod_path =
            this.path ~ std.path.dirSeparator ~ name ~ std.path.dirSeparator;
        return std.file.exists(mod_path) && std.file.isDir(mod_path);
    }
}

// TODO: detect circular dependencies
// for now we assume that the input program
// is acyclic but this needs to be resolved
// otherwise if we are given a cyclic program
// then the compiler will likely crash with a nasty error.
Krug_Project build_krug_project(ref Source_File main_source_file) {
	err_logger.Verbose("Building program tree `" ~ main_source_file.path ~ "`");

    auto tokens = new Lexer(main_source_file.contents).tokenize();
    Load_Directive[] dirs = collect_deps(tokens);

    string main_module_path = buildNormalizedPath(absolutePath(main_source_file.path));
    auto project = Krug_Project(strip_file(main_module_path));

    auto main_mod = new Module();
    project.graph.register_module(main_mod);

    // TODO: this is kind of messy
    main_mod.token_streams["main"] = tokens;

    foreach (dir; dirs) {
        Token[] sub_modules = dir[1];

        string module_name = dir[0].lexeme;

        if (!project.module_exists(module_name)) {
            err_logger.Error("No such module '" ~ module_name ~ "'.");
            continue;
        }

        Module loaded_module = project.load_module(module_name);
        project.graph.add_edge(main_mod.name, loaded_module);
    }

    return project;
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