module kt;

import std.conv;

interface Type {
	bool cmp(Type t);
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

class Array_Type : Type {
	Type base;
	size_t len;

	this(Type base, size_t len) {
		this.base = base;
		this.len = len;
	}

	uint get_width() {
		return base.get_width();
	}

	bool cmp(Type t) {
		if (auto arr = cast(Array_Type) t) {
			// if the base types are the same
			// these types are equal.
			return arr.base.cmp(base);
		}
		return false;
	}

	override string toString() {
		return "[" ~ to!string(base) ~ "; " ~ to!string(len) ~ "]";
	}
}

class Pointer_Type : Type {
	Type base;

	this(Type base) {
		this.base = base;
	}

	uint get_width() {
		// ptr size is what?
		return 8;
	}

	bool cmp(Type kt) {
		if (auto ptr = cast(Pointer_Type) kt) {
			return base.cmp(ptr.base);
		}
		return false;
	}

	override string toString() {
		return "*" ~ to!string(base);
	}
}

class Structure_Type : Type {
	Type[] types;

	this() {}

	this(Type[] types...) {
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

	bool cmp(Type kt) {
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

class Void_Type : Type {
	bool cmp(Type other) {
		if (auto v = cast(Void_Type) other) {
			return true;
		}
		return false;
	}

	uint get_width() {
		// TEMPORARY FIXME
		// this is a hack to avoid some type inference
		// spills in the x64 backend
		// this WAS set to zero but this fucks up some
		// of the codegen
		// so to keep everything somewhat working im going
		// to make void == 4 
		return 4;
	}

	override string toString() {
		return "void";
	}
}

class Integer_Type : Type {
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
	bool cmp(Type other) {
		if (auto i = cast(Integer_Type) other) {
			return i.width == width && i.signed == signed;
		}
		return false;
	}

	override string toString() {
		return (signed ? "s" : "u") ~ to!string(width);
	}
}

class Floating_Type : Type {
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

	bool cmp(Type other) {
		if (auto f = cast(Floating_Type) other) {
			return f.width == width && f.signed == signed;
		}
		return false;
	}

	override string toString() {
		return "f" ~ to!string(width);
	}
}
