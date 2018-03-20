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

    BB_Node idom(BB_Node b) {
        return dom_tree[b][0];
    }

    /*
        DF(d) = 
            there exists a p
                in the set of pred(n)
            such that
                d dominates p
            and 
                d does not sdom n

        or in cytron, et al...

        for all nodes b,
            if len(b.edges) >= 2
                foreach p; b.edges
                    runner = p
                    while runner != doms[b]
                        runners df set ~= b
                        runner = doms[runner]
    */

    // a dom b
    bool dom(BB_Node a, BB_Node b) {
        auto b_doms = dom_tree[b];
        if (b_doms.canFind(a)) {
            return true;
        }
        return false;
    }

    // a strictly dominates b
    bool sdom(BB_Node a, BB_Node b) {
        return a !is b && dom(a, b);
    }

    // the dominance frontier of 
    // d, i dont think this is correct... 
    BB_Node[] df(BB_Node d) {
        BB_Node[] frontier;
        foreach (p; d.edges) {
            auto p_domtree = dom_tree[p];
            if (sdom(d, p)) {
                frontier ~= p;
            }
        }
        return frontier;
    }

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