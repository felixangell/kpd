module kir.cfg_builder;

import std.conv;

import logger;

import kir.cfg;
import kir.instr;
import kir.ir_mod;

void add_edge_to(Graph_Node!Basic_Block a, Graph_Node!Basic_Block b) {
    logger.Verbose(a.value.name(), " -> ", b.value.name());
    a.add_edge(b);
}

// builds a control flow graph
class CFG_Builder {
    // the graph created from the builder
    Control_Flow_Graph graph;
    Function f;
    int block_ptr = 0;

    this(Function f) {
        this.graph = new Control_Flow_Graph;
        this.f = f;
    }

    bool is_flow_instr(Instruction i) {
        if (cast(Jump)i || cast(If)i) {
            return true;
        }
        return false;
    }

    void analyze_instr(Graph_Node!Basic_Block bb, Instruction instr) {
        if (auto jump = cast(Jump) instr) {
            auto target_node = graph.get_node_by_label(jump.label);
            bb.add_edge_to(target_node);
        }
        else if (auto iff = cast(If) instr) {
            auto if_true = graph.get_node_by_label(iff.a);
            auto if_false = graph.get_node_by_label(iff.b);
            bb.add_edge_to(if_true);
            bb.add_edge_to(if_false);
        }
        else {
            logger.Fatal("Unhandled instruction when building CFG ", to!string(instr));
        }
    }

    Graph_Node!Basic_Block analyze_bb(Basic_Block bb) {
        logger.Verbose("- Analyzing ", bb.name());
        auto node = graph.get_node(bb.name());
        foreach (instr; bb.instructions) {
            analyze_instr(node, instr);        
        }
        return node;
    }

    // builds a control flow graph of
    // the given function.
    void build() {
        // first we register all the basic blocks
        // in the graph as nodes.
        foreach (bb; f.blocks) {
            graph.add_node(bb);
        }

        Graph_Node!Basic_Block last;
        while (block_ptr < f.blocks.length) {
            auto analyzed_bb = analyze_bb(f.blocks[block_ptr++]);
            
            // join the last two analyzed nodes
            // if the last node does not jump
            // elsewhere.
            if (last !is null 
                    && !is_flow_instr(last.value.last_instr())) {
                last.add_edge_to(analyzed_bb);
            }
            last = analyzed_bb;
        }
    }
}

// builds the control flow graph for
// all of the functions in the ir module
void build_graphs(Kir_Module mod) {
    foreach (func; mod.functions) {
        auto cfg_builder = new CFG_Builder(func);
        cfg_builder.build();
    }
}