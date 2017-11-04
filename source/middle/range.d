// scope is a keyword so we'll dump it in
// a module called range for now
module sema.range;

class Scope {
	Scope outer;

	this() {
		this(null);
	}

	this(Scope outer) {
		this.outer = outer;
	}
}