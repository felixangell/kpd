module kt;

import std.conv;

interface Kir_Type {
	bool cmp(Kir_Type t);
	string toString();
	uint get_width();
};
	 
Floating_Type f32, f64;
static this() {
	f32 = new Floating_Type(32, true);
	f64 = new Floating_Type(64, true);
}

Integer_Type[uint] signed_type_cache;
Integer_Type[uint] unsigned_type_cache;

Floating_Type get_float(uint width) {
	final switch (width) {
	case 32:
		return f32;
	case 64:
		return f64;
	}
	assert(0);
}

Integer_Type get_int(uint width) {
	if (width in signed_type_cache) {
		return signed_type_cache[width];
	}
	auto i = new Integer_Type(width, true);
	signed_type_cache[width] = i;
	return i;
}

Integer_Type get_uint(uint width) {
	if (width in unsigned_type_cache) {
		return unsigned_type_cache[width];
	}
	auto i = new Integer_Type(width, false);
	unsigned_type_cache[width] = i;
	return i;
}

class Array_Type : Kir_Type {
	Kir_Type base;

	this(Kir_Type base) {
		this.base = base;
	}

	uint get_width() {
		return base.get_width();
	}

	bool cmp(Kir_Type t) {
		if (auto arr = cast(Array_Type) t) {
			// if the base types are the same
			// these types are equal.
			return arr.base.cmp(base);
		}
		return false;
	}

	override string toString() {
		return "[" ~ to!string(base) ~ "]";
	}
}

class Pointer_Type : Kir_Type {
	Kir_Type base;

	this(Kir_Type base) {
		this.base = base;
	}

	uint get_width() {
		// ptr size is what?
		return 8;
	}

	bool cmp(Kir_Type kt) {
		if (auto ptr = cast(Pointer_Type) kt) {
			return base.cmp(ptr.base);
		}
		return false;
	}

	override string toString() {
		return "*" ~ to!string(base);
	}
}

class Structure_Type : Kir_Type {
	Kir_Type[] types;

	this() {}

	this(Kir_Type[] types...) {
		foreach (t; types) {
			this.types ~= t;
		}
	}

	uint get_width() {
		uint size = 0;
		foreach (t; types) {
			size += t.get_width();
		}
		return size;
	}

	bool cmp(Kir_Type kt) {
		auto other = cast(Structure_Type) kt;
		if (!other) {
			return false;
		}

		if (other.types.length != types.length) {
			return false;
		}

		foreach (i, t; other.types) {
			if (!t.cmp(other.types[i])) {
				return false;
			}
		}

		return true;
	}

	override string toString() {
		string type_list = "";
		foreach (i, t; types) {
			if (i > 0)
				type_list ~= ",";
			assert(t !is null);
			type_list ~= to!string(t);
		}
		return "{" ~ type_list ~ "}";
	}
}

class Void_Type : Kir_Type {
	bool cmp(Kir_Type other) {
		if (auto v = cast(Void_Type) other) {
			return true;
		}
		return false;
	}

	uint get_width() {
		return 0;
	}

	override string toString() {
		return "void";
	}
}

class Integer_Type : Kir_Type {
	uint width;
	bool signed;

	this(uint width, bool signed) {
		this.width = width;
		this.signed = signed;
	}

	uint get_width() {
		return width / 8;
	}

	// if they are both integer types
	// and the widths are the same,
	// they are equivalent.
	bool cmp(Kir_Type other) {
		if (auto i = cast(Integer_Type) other) {
			return i.width == width && i.signed == signed;
		}
		return false;
	}

	override string toString() {
		return (signed ? "s" : "u") ~ to!string(width);
	}
}

class Floating_Type : Kir_Type {
	uint width;
	bool signed;

	this(uint width, bool signed) {
		this.width = width;
		this.signed = signed;
	}

	uint get_width() {
		// ptr size is what?
		return width / 8;
	}

	bool cmp(Kir_Type other) {
		if (auto f = cast(Floating_Type) other) {
			return f.width == width && f.signed == signed;
		}
		return false;
	}

	override string toString() {
		return "f" ~ to!string(width);
	}
}
