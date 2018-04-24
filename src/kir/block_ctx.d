module kir.block_ctx;

import std.stdio;

import kir.instr;
import sema.type;

class Block_Context {
	Function parent;

	long addr_ptr = 0;
	long[string] locals;
	uint alloc_instr_addr;

	this(Function parent) {
		this.parent = parent;
	}

	long size() {
		version (OSX) {
			import std.algorithm.comparison : max;
			return max(16, addr_ptr);
		} else {
			return addr_ptr;			
		}
	}

	long push_local(string name, Type t) {
		// floating types are stored in xmm0 ... xmmN
		// registers which are 128 bits or 16 bytes
		// in size.
		if (cast(Floating)t) {
			return push_local(name, 16);
		}
		return push_local(name, t.get_width());
	}

	long push_local(string name, int width) {
		long alloc_addr = addr_ptr;
		locals[name] = alloc_addr;
		addr_ptr += width;
		return alloc_addr;
	}

	// FIXME
	// return -1 if the name is not a local.
	long get_addr(string name) {
		if (name !in locals) {
			writeln("NO LOCAL '", name, "' in '", parent.name, "'!");
			foreach (k, v; locals) {
				writeln(k, " => ", v);
			}
			return -1;
		}
		return locals[name];
	}
}