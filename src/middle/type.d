module sema.type;

import std.conv;
import std.algorithm.searching : countUntil;

static int align_by(int n, int m) {
    int rem = n % m;
    return (rem == 0) ? n : n - rem + m;
}

static Type conv_prim(string name) {
	final switch (name) {
	case "u8":
		return get_int(false, 8);
	case "u16":
		return get_int(false, 16);
	case "u32":
		return get_int(false, 32);
	case "u64":
		return get_int(false, 64);

	case "s8":
		return get_int(true, 8);
	case "s16":
		return get_int(true, 16);
	case "s32":
		return get_int(true, 32);
	case "s64":
		return get_int(true, 64);
	
	case "f32":
		return get_int(true, 32);
	case "f64":
		return get_int(true, 64);
	
	case "rune":
		return get_rune();
	case "bool":
		return get_bool();
	case "string":
		return get_string();
	}
	assert(0);
}

static Type get_int(bool signed, int width) {
	return new Integer(signed, width);
}

static Type get_float(bool signed, int width) {
	return new Floating(signed, width);
}

static Type get_rune() {
	return new Rune();
}

static Type get_bool() {
	return new Boolean();
}

static Type get_string() {
	return new Structure(
		// len, pointer to string
		get_int(false, 64),
		new Pointer(get_int(false, 8)),
	);
}

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

	PRIMITIVE_TYPES["string"] = null;
}

static void register_types(string...)(string types) {
	foreach (name; types) {
		assert(name !in PRIMITIVE_TYPES);
		PRIMITIVE_TYPES[name] = new Type_Operator(name);
	}
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

class Boolean : Integer {
	this() {
		super(false, 8);
	}

	override bool cmp(Type other) {
		if (cast(Boolean)other) {
			return true;
		}
		return false;
	}

	override uint get_width() {
		return width / 8;
	}

	override string toString() const {
		return "bool";
	}	
}

class Rune : Integer {
	this() {
		super(true, 32);
	}

	override bool cmp(Type other) {
		if (cast(Rune)other) {
			return true;
		}
		return false;
	}

	override string toString() const {
		return "rune";
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
	ulong length;
	Type base;

	this(Type base, ulong length, Type[] args = []) {
		super("arr", args);
		this.length = length;
		this.base = base;
	}

	override bool cmp(Type other) {
		if (auto a = cast(Array)other) {
			return a.base.cmp(base);
		}
		return false;
	}

	override uint get_width() {
		// FIXME ulong here.
		return base.get_width() * cast(uint)(length);
	}

	override string toString() const {
		return "arr (" ~ to!string(base) ~ ") * " ~ to!string(length);
	}
}

class Structure : Type {
	string[] names;

	this(Type[] args...) {
		super("struct", args);
	}

	this(Type[] args, string[] names = []) {
		super("struct", args);
		this.names = names;
	}

	auto get_field_index(string name) {
		return names.countUntil(name);
	}

	Type get_field_type(string name) {
		auto idx = names.countUntil(name);
		return types[idx];
	}

	override bool cmp(Type other) {
		assert(0);
	}

	override uint get_width() {
		uint size = 0;
		foreach (t; types) {
			size += align_by(t.get_width(), 8);
		}
		return size;
	}

	override string toString() const {
		return "struct " ~ to!string(types);
	}
}

// hm!
class Mutable : Type {
	Type base;

	this(Type base, Type[] args = []) {
		super("mut", args);
		this.base = base;
	}

	override bool cmp(Type other) {
		if (auto mut = cast(Mutable)other) {
			return mut.base.cmp(base);
		}
		return false;
	}

	override uint get_width() {
		return base.get_width();
	}

	override string toString() const {
		return "mut " ~ to!string(base);
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

class Module_Info : Type {
	string[] names;

	this(Type[] args...) {
		super("mod_info", args);
	}

	this(Type[] args, string[] names = []) {
		super("mod_info", args);
		this.names = names;
	}

	Type get_field_type(string name) {
		auto idx = names.countUntil(name);
		return types[idx];
	}

	override bool cmp(Type other) {
		assert(0);
	}

	override uint get_width() {
		assert(0);
	}

	override string toString() const {
		return "mod_info " ~ to!string(types);
	}
}