module opt.dom;

import std.stdio;

import kir.instr;
import kir.cfg;

import std.algorithm.mutation;

class Dominator_Tree_Node {
    Dominator_Tree_Node parent;
    Dominator_Tree_Node[] children;
    Basic_Block block;

    this(Basic_Block block) {
        this.block = block;
    }

    Dominator_Tree_Node idom() {
        return parent;
    }

    // TODO strict dominator
    bool is_dom_by(Dominator_Tree_Node node) {
        if (this !is node) {
            return true;
        }
        return false;
    }

    Dominator_Tree_Node[] doms() {
        Dominator_Tree_Node[] doms;
        auto dom = this;
        while (dom !is null) {
            doms ~= dom;
            dom = dom.parent;
        }
        return doms;
    }
}

bool dominates(Control_Flow_Graph g, Basic_Block a, Basic_Block b) {    
    writeln(a.name(), b.name());
    if (a is b) {
        return true;
    }

    auto preds = g.get_node(b.name()).edges;
    if (preds.length == 0) {
        return false;
    }

    foreach (p; preds) {
        if (p is b) {
            continue;
        }

        if (!g.dominates(a, p.value)) {
            return false;
        }
    }
    
    return true;
}

class Dominator_Tree {
    Dominator_Tree_Node[] nodes;

    void build(Function f) {
        Control_Flow_Graph g = f.graph;
        Basic_Block[][Basic_Block] doms_map;
        Dominator_Tree_Node[Basic_Block] nodes_map;

        foreach (n; g.nodes.byValue) {
            Basic_Block[] doms;
            foreach (o; g.nodes.byValue) {
                if (o.value == n.value) {
                    continue;
                }

                if (g.dominates(o.value, n.value)) {
                    doms ~= o.value;
                }
            }
            doms_map[n.value] = doms;
        }    

        foreach (n; g.nodes.byValue) {
            auto dom_node = new Dominator_Tree_Node(n.value);
            nodes_map[n.value] = dom_node;
            nodes ~= dom_node;
        }

        auto remove_dom = delegate bool(Basic_Block node, Basic_Block dom) {
            Basic_Block[] doms = doms_map[node];
            foreach (i, other; doms) {
                if (dom !is other) {
                    doms = remove(doms[], i);
                    doms_map[node] = doms;
                    return true;
                }
            }
            return false;
        };

        void delegate(Basic_Block) create;
        create = delegate(Basic_Block root) {
            foreach (n; g.nodes.byValue) {
                if (remove_dom(n.value, root) && doms_map[n.value].length == 1) {
                    nodes_map[root].children ~= nodes_map[n.value];
                    nodes_map[n.value].parent = nodes_map[root];
                }
            }

            foreach (n; g.nodes.byValue) {
                auto v = n.value;
                if (doms_map[n.value].length == 1) {
                    create(v);
                }
            }
        };

        create(f.blocks[0]);
    }
}