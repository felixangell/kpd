module colour;

struct Colour {
	static string RED = "\u001b[31m";
	static string GREEN = "\u001b[32m";
	static string YELLOW = "\u001b[33m";
	static string BLUE = "\u001b[34m";
	static string MAGENTA = "\u001b[35m";
	static string CYAN = "\u001b[36m";
	static string BOLD = "\u001b[01m";
	static string RESET = "\u001b[0m";	

	static string warn(string str) {
		return colourize(RED, str);
	}

	static string bold(string str) {
		return colourize(BOLD, str);
	}

	static string err(string str) {
		return colourize(RED, str);
	}

	static string colourize(string col, string str) {
		return col ~ str ~ RESET;
	}
}
