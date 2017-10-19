module block_scope;

class Scope {
	Scope outer;

	this() {
		this(null);
	}

	this(Scope outer) {
		this.outer = outer;
	}
}