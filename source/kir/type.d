module kt;

import std.conv;

interface Kir_Type {
	bool cmp(Kir_Type t);
};

Integer_Type[uint] signed_type_cache;
Integer_Type[uint] unsigned_type_cache;

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

class Structure_Type : Kir_Type {
	Kir_Type[] types;

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
		string type_list;
		foreach (i, t; types) {
			if (i > 0) type_list ~= ",";
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