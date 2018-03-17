module opt.dom;

import std.stdio;
import std.algorithm : canFind;
import std.range.primitives;

import kir.instr;
import kir.cfg;

class Dominator_Tree {
    /*

    dfs(source)
    foreach w:
        graph remove w;
        dfs(source)
        all vertices that were visited but arent now
        are dominated by W

    */

    BB_Node[][BB_Node] dom_tree;

    // dfs on the vertex to see what nodes are 
    // available.
    BB_Node[] dfs(BB_Node node) {
        BB_Node[] to_visit;
        to_visit ~= node;

        bool[BB_Node] visited;

        while (to_visit.length > 0) {
            auto n = to_visit.back;
            to_visit.popBack();
            visited[n] = true;

            foreach (edge; n.edges) {
                if (edge !in visited) {
                    to_visit ~= edge;
                }
            }
        }

        return visited.keys;
    }

    // this is really slow, a very naive algo for
    // computing the dominator tree
    BB_Node[][BB_Node] build(Function f) {
        auto graph_nodes = f.graph.nodes.dup;
        
        auto root = graph_nodes[f.blocks[0].name()];
        auto root_dfs = dfs(root);
        dom_tree[root] = root_dfs;

        foreach (k, v; graph_nodes) {
            // skip root node
            if (v is root) {
                continue;
            }

            auto v_dfs = dfs(v);

            // all nodes that WERE visited but
            // arent now dominate V
            BB_Node[] v_doms = [];
            foreach (dom; root_dfs) {
                if (!v_dfs.canFind(dom)) {
                    v_doms ~= dom;
                }
            }

            dom_tree[v] = v_doms;
        } 

        return dom_tree;
    }
}  