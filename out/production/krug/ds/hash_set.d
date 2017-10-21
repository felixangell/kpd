module ds;

import std.algorithm : joiner, map;
import std.conv : to;
import std.traits : isImplicitlyConvertible, ParameterTypeTuple;
import std.range : ElementType, isInputRange;

final class Hash_Set(E) {
    this() {}

    this(E[] elems...) {
        insert(elems);
    }

    void insert(Stuff)(Stuff stuff) if (isImplicitlyConvertible!(Stuff, E)) {
        aa_[*(cast(immutable(E)*)&stuff)] = [];
    }

    void insert(Stuff)(Stuff stuff) if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, E)) {
        foreach (e; stuff) {
            aa_[*(cast(immutable(E)*)&e)] = [];
        }
    }

    void opOpAssign(string op : "~", Stuff)(Stuff stuff) {
        insert(stuff);
    }

    void remove(E e) {
        aa_.remove(*(cast(immutable(E)*)&e));
    }
    alias remove removeKey;

    void removeAll() {
        aa_ = null;
    }

    size_t length() @property const {
        return aa_.length;
    }

    size_t empty() @property const {
        return !aa_.length;
    }

    bool opBinaryRight(string op : "in")(E e) const {
        return (e in aa_) !is null;
    }

    auto opSlice() const {
        // TODO: Implement using AA key range once availabe in release DMD/druntime
        // to avoid allocation.
        return cast(E[])(aa_.keys);
    }

    override string toString() const {
        // Only provide toString() if to!string() is available for E (exceptions are
        // e.g. delegates).
        static if (is(typeof(to!string(E.init)) : string)) {
            return "{" ~ to!string(joiner(map!`to!string(a)`(aa_.keys), ", ")) ~ "}";
        } 
        else {
            // Cast to work around Object not being const-correct.
            return (cast()super).toString();
        }
    }

    override bool opEquals(Object other) const {
        auto rhs = cast(const(Hash_Set))other;
        if (rhs) {
            return aa_ == rhs.aa_;
        }
        // Cast to work around Object not being const-correct.
        return (cast()super).opEquals(other);
    }

private:
    alias void[0] Void;
    Void[immutable(E)] aa_;
}