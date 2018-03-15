module kir.cfg;

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

class Control_Flow_Graph {
    Graph_Node!Basic_Block[string] nodes;

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