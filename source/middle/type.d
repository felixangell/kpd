module sema.type;

import std.conv;
import containers.hashmap;

static HashMap!(string, Type_Operator) PRIMITIVE_TYPES;

static this() {
	register_types("s8", "s16", "s32", "s64", "u8", "u16", "u32", "u64", "f32",
			"f64", "string", "rune", "bool", "void", // TODO define these types properly.
			"int", "uint",);
}

static void register_types(string...)(string types) {
	foreach (name; types) {
		assert(name !in PRIMITIVE_TYPES);
		PRIMITIVE_TYPES[name] = new Type_Operator(name);
	}
}

static Type_Operator prim_type(string type_name) {
	assert(type_name in PRIMITIVE_TYPES);
	return PRIMITIVE_TYPES[type_name];
}

class Type {
	string name;
	Type[] types;

	this(Type[] types) {
		this.types = types;
	}

	this(string name, Type[] types) {
		this.name = name;
		this.types = types;
	}

	string get_name() {
		return name;
	}

	abstract override string toString() const;
}

class Type_Variable : Type {
	uint id;
	Type instance;

	static uint next_id = -1;

	this(Type[] types = []) {
		super(types);
		this.id = ++next_id;
	}

	override string toString() const {
		if (instance !is null) {
			return to!string(instance);
		}
		return name;
	}

	override string get_name() {
		static char next_ascii = 'a';
		if (name.length != 0) {
			return this.name;
		}

		this.name = to!string(next_ascii++);
		return this.name;
	}
}

class Type_Operator : Type {
	this(string name, Type[] types) {
		super(name, types);
	}

	this(string name) {
		super(name, []);
	}

	override string toString() const {
		switch (types.length) {
		case 0:
			return name;
		case 2:
			return name ~ " " ~ to!string(types[0]) ~ " " ~ to!string(types[1]);
		default:
			return to!string(types);
		}
	}
}

class Function : Type {
	Type ret;

	this(Type ret, Type[] args) {
		super("fn", args);
		this.ret = ret;
	}

	override string toString() const {
		return to!string(types) ~ " -> " ~ to!string(ret);
	}
}
