module sema.type;

import std.conv;

static Type[string] PRIMITIVE_TYPES;

static this() {
	PRIMITIVE_TYPES = [
		"s8": new Integer(true, 8),
		"s16": new Integer(true, 16),
		"s32": new Integer(true, 32),
		"s64": new Integer(true, 64),

		"u8": new Integer(false, 8),
		"u16": new Integer(false, 16),
		"u32": new Integer(false, 32),
		"u64": new Integer(false, 64),

		"f32": new Floating(true, 32),
		"f64": new Floating(true, 64),

		"bool": new Integer(false, 8),
		"rune": new Integer(true, 32),
		"void": new Void(),
	];

	PRIMITIVE_TYPES["string"] = new Structure(
		// len, pointer to string
		prim_type("u64"),
		new Pointer(prim_type("u8")),
	);
}

static void register_types(string...)(string types) {
	foreach (name; types) {
		assert(name !in PRIMITIVE_TYPES);
		PRIMITIVE_TYPES[name] = new Type_Operator(name);
	}
}

static Type prim_type(string type_name) {
	assert(type_name in PRIMITIVE_TYPES, to!string(type_name) ~ " not in primitives?!");
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

	abstract bool cmp(Type other);

	string get_name() {
		return name;
	}

	abstract uint get_width();

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

	override bool cmp(Type other) {
		assert(0);
	}

	override uint get_width() {
		assert(0);
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

	override bool cmp(Type other) {
		assert(0);
	}

	override uint get_width() {
		return 0;
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

class Void : Type_Operator {
	this() {
		super("void");
	}

	override bool cmp(Type other) {
		if (cast(Void)other) {
			return true;
		}
		return false;
	}

	override uint get_width() {
		return 1;
	}


	override string toString() const {
		return "void";
	}
}

class Integer : Type_Operator {
	bool signed;
	uint width;

	this(bool signed, uint width) {
		super((signed ? "s" : "u") ~ to!string(width));
		this.signed = signed;
		this.width = width;
	}

	override bool cmp(Type other) {
		if (auto o = cast(Integer)other) {
			return signed == o.signed && width == o.width;
		}
		return false;
	}

	override uint get_width() {
		return width / 8;
	}

	override string toString() const {
		return name;
	}
}

class Floating : Type_Operator {
	bool signed;
	uint width;

	this(bool signed, uint width) {
		super((signed ? "s" : "u") ~ to!string(width));
		this.signed = signed;
		this.width = width;
	}

	override bool cmp(Type other) {
		if (auto o = cast(Floating)other) {
			return signed == o.signed && width == o.width;
		}
		return false;
	}

	override uint get_width() {
		return width / 8;
	}

	override string toString() const {
		return name;
	}
}

class Array : Type {
	Type base;

	this(Type base, Type[] args = []) {
		super("arr", args);
		this.base = base;
	}

	override bool cmp(Type other) {
		if (auto a = cast(Array)other) {
			return a.base.cmp(base);
		}
		return false;
	}

	override uint get_width() {
		// FIXME sizeof should be 
		// with the length of the array.
		return base.get_width();
	}

	override string toString() const {
		return "arr " ~ to!string(base);
	}
}

class Structure : Type {
	this(Type[] args...) {
		super("struct", args);
	}

	override bool cmp(Type other) {
		assert(0);
	}

	override uint get_width() {
		uint size = 0;
		foreach (t; types) {
			size += t.get_width();
		}
		return size;
	}

	override string toString() const {
		return "struct " ~ to!string(types);
	}
}

class Pointer : Type {
	Type base;

	this(Type base, Type[] args = []) {
		super("ptr", args);
		this.base = base;
	}

	override bool cmp(Type other) {
		if (auto ptr = cast(Pointer)other) {
			return ptr.base.cmp(base);
		}
		return false;
	}

	override uint get_width() {
		return 8;
	}

	override string toString() const {
		return "ptr " ~ to!string(base);
	}
}

class Fn : Type {
	Type ret;

	this(Type ret, Type[] args) {
		super("fn", args);
		this.ret = ret;
	}

	override bool cmp(Type other) {
		assert(0);
	}

	override uint get_width() {
		assert(0);
	}

	override string toString() const {
		return to!string(types) ~ " -> " ~ to!string(ret);
	}
}
