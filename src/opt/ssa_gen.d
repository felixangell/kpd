module opt.ssa_gen;

import std.typecons;
import std.stdio;
import std.conv;
import std.algorithm : remove, sort;
import std.range.primitives;
import std.path;
import std.file;
import std.process;
import std.random;

import kt;
import kir.ir_mod;
import kir.instr;
import kir.cfg;

import opt.dom;
import opt.pass;

import logger;

string bb_to_string(BB_Node b) {
	return b.value.name();
}

// TERRIBLE HACKY THING 
// so that i can see the visual otuput.
// this is very temporary!

string graph_html_doc = `<!doctype html><html><head><title>Krug Control Flow Graph</title><script type="text/javascript" src="http://visjs.org/dist/vis.js"></script><link href="http://visjs.org/dist/vis-network.min.css" rel="stylesheet" type="text/css" /><style type="text/css">.mynetwork {display: inline-block;float: left;width: 600px;height: 400px;border: 1px solid lightgray;}</style></head><body><p>Krug graph stuff:</p>`;
string html_body;
string js_body = `<script type="text/javascript">`;

void add_graph(string graph_name, string data_set, string edges, string options = "") {
	html_body ~= `<div class="mynetwork" id="` ~ graph_name ~ `"></div>`;
	js_body ~= `
	// create an array with nodes
	var ` ~ graph_name ~ `_nodes = new vis.DataSet([` ~ data_set ~ `]);

	// create an array with edges
	var ` ~ graph_name ~ `_edges = new vis.DataSet([` ~ edges ~ `]);

	// create a network
	var ` ~ graph_name ~ `_container = document.getElementById('` ~ graph_name ~ `');
	var ` ~ graph_name ~ `_data = {
	nodes: ` ~ graph_name ~ `_nodes,
	edges: ` ~ graph_name ~ `_edges
	};
	var ` ~ graph_name ~ `_options = {` ~ options ~ `};
	var ` ~ graph_name ~ `_network = new vis.Network(` ~ graph_name ~ `_container, ` ~ graph_name ~ `_data, ` ~ graph_name ~ `_options);
	`;
};

void write_graph() {
	js_body ~= `</script>`;
	html_body ~= `</body></html>`;
	graph_html_doc ~= html_body ~ js_body;

	string file_name = "cfg-dump-" ~ thisProcessID.to!string(36) ~ "-" ~ uniform!uint.to!string(36) ~ ".html";
	auto temp_file = File(file_name, "w");
	temp_file.write(graph_html_doc);
	temp_file.close();
}

// TERRIBLE hacky code but fuck it!
// view-source:http://visjs.org/examples/network/basicUsage.html
void dump_graph(Control_Flow_Graph g) {
	string data_set;

	int idx = 0;
	foreach (bb; g.nodes.byValue) {
		if (idx++ > 0) {
			data_set ~= ",";
			data_set ~= '\n';
		}

		auto basic_block = bb.value;
		data_set ~= "{id:" ~ to!string(basic_block.id) ~ ",label:'" ~ basic_block.name() ~ "'}";
	}

	string edges;
	idx = 0;
	foreach (bb; g.nodes.byValue) {
		foreach (edge; bb.edges) {
			if (idx++ > 0) {
				edges ~= ',';
				edges ~= '\n';
			}
			edges ~= "{from:" ~ to!string(bb.value.id) ~ ", to: " ~ to!string(edge.value.id) ~ ", arrows:'to', dashes:true}";
		}
	}

	add_graph("cfg", data_set, edges);
}

// for now this pass simply
// evaluates simple expressions in
// binary expressions _only_
class SSA_Builder : Optimisation_Pass {

	void ssa_func(Function f) {
		// prototype, NOOP!
		if (f.blocks.length == 0) {
			return;
		}

		auto entry_bb_name = f.blocks[0].name();

		auto dom_tree_builder = new Dominator_Tree();
		auto dom_tree = dom_tree_builder.build(f);
		foreach (k, doms; dom_tree) {
			writeln("node ", k.bb_to_string(), " dominates:");
			foreach (d; doms) {
				writeln("- ", d.bb_to_string());
			}
			writeln;
		}
	}

	void process(Kir_Module mod) {
		foreach (func; mod.functions) {
			ssa_func(func);
		}
	}

	override string toString() {
		return "Static Single Assignment";
	}
}