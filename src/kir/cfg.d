module kir.cfg;

import std.range.primitives;
import std.conv;
import std.algorithm: canFind;
import kir.instr;

class Graph_Node(T) {
    T value;
    Graph_Node!T[] edges;

    this(T value, Graph_Node!T[] edges = []) {
        this.value = value;
        this.edges = edges;
    }

    void add_edge(Graph_Node!T edge) {
        edges ~= edge;
    }
}

alias BB_Node = Graph_Node!Basic_Block;

// todo we could easily make this reusable.
class Control_Flow_Graph {
    BB_Node[string] nodes;

    BB_Node[] preds(BB_Node node) {
        BB_Node[] preds;
        foreach (entry; nodes.byKeyValue) {
            if (entry.value.edges.canFind(node)) {
                // val has an edge to our node
                // this means that val pred of node
                preds ~= entry.value;
            }
        }
        return preds;
    }

    BB_Node[] succs(BB_Node node) {
        BB_Node[] succs;
        
        bool[BB_Node] visited;
        BB_Node[] work;
        work ~= node;
        
        while (work.length > 0) {
            auto top = work.back;
            visited[top] = true;
            succs ~= top;
            work.popBack();
            
            foreach (e; top.edges) {
                if (e !in visited) {
                    work ~= e;
                }
            }
        }

        return succs;
    }

    BB_Node add_node(Basic_Block b) {
        auto node = new BB_Node(b);
        nodes[b.name()] = node;
        return node;
    }

    BB_Node get_node_by_label(Label l) {
        assert(l.reference !is null);
        return get_node(l.reference.name());
    }

    BB_Node get_node(string name) {
        assert(name in nodes);
        return nodes[name];
    }
}