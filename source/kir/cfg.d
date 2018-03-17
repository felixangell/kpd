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

// todo we could easily make this reusable.
class Control_Flow_Graph {
    Graph_Node!Basic_Block[string] nodes;

    Graph_Node!Basic_Block[] preds(Graph_Node!Basic_Block node) {
        Graph_Node!Basic_Block[] preds;
        foreach (entry; nodes.byKeyValue) {
            if (entry.value.edges.canFind(node)) {
                // val has an edge to our node
                // this means that val pred of node
                preds ~= entry.value;
            }
        }
        return preds;
    }

    Graph_Node!Basic_Block[] succs(Graph_Node!Basic_Block node) {
        Graph_Node!Basic_Block[] succs;
        
        bool[Graph_Node!Basic_Block] visited;
        Graph_Node!Basic_Block[] work;
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

    Graph_Node!Basic_Block add_node(Basic_Block b) {
        auto node = new Graph_Node!Basic_Block(b);
        nodes[b.name()] = node;
        return node;
    }

    Graph_Node!Basic_Block get_node_by_label(Label l) {
        assert(l.reference !is null);
        return get_node(l.reference.name());
    }

    Graph_Node!Basic_Block get_node(string name) {
        assert(name in nodes);
        return nodes[name];
    }
}