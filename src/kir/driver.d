module kir.driver;

import ast;
import krug_module;
import sema.type;
import sema.infer : Type_Environment;
import kir.ir_mod;
import kir.conv_type;
import kir.builder;
import logger;
import kir.ir_verify;

private IR_Module[string] modules;

void declare_func(IR_Module mod, Type_Environment env, ast.Function_Node func) {
	Type return_type = new Void();
	if (func.return_type !is null) {
		return_type = env.conv_type(func.return_type);
	}

	if (func.has_attribute("c_func")) {
		auto cfunc = new kir.instr.Function(func.name.lexeme, return_type, mod);
		mod.c_funcs[cfunc.name] = cfunc;
	}
	else {
		mod.add_function(func.name.lexeme, return_type);
	}
}

void pre_build(IR_Module mod, Type_Environment env, ref AST as_tree) {
	foreach (ref node; as_tree) {
		if (auto func_node = cast(ast.Function_Node) node) {
			mod.declare_func(env, func_node);
		}
	}
}

// first we do a pass over every single
// krug program that registers the functions
// in the ir module. the BODY of the functions
// are not code generated till later.
IR_Module build_ir(Module mod) {
	mod.ir_mod = new IR_Module(mod.name);

	// 1st pass.
	foreach (ref sub_mod_name, as_tree; mod.as_trees) {
		// we can register the dependencies in this pass
		// this is based off the assumption that because
		// our krug program is sorted, we should be 
		// building the modules in order where
		// all modules should be known.
		foreach (ref key, mod; mod.edges) {
			mod.ir_mod.add_dependency(modules[key]);
		}

		mod.ir_mod.pre_build(mod.sym_tables.env, as_tree);
	}
	
	// 2nd pass.
	foreach (ref sub_mod_name, as_tree; mod.as_trees) {
		auto ir_builder = new IR_Builder(mod, sub_mod_name);
		ir_builder.setup_sym_table(mod, sub_mod_name, as_tree);

		logger.verbose(" - ", mod.name, "::", sub_mod_name);

		auto ir_mod = ir_builder.build(mod, as_tree);
		if (VERBOSE_LOGGING) ir_mod.dump();
		new IR_Verifier(ir_mod);

	}

	modules[mod.name] = mod.ir_mod;

	return mod.ir_mod;
}
