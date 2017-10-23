module scope_sys;

class Scope {
	Scope outer;

	this() {
		this(null);
	}

	this(Scope outer) {
		this.outer = outer;
	}
}