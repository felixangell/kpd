module cflags;

enum VERSION = "0.0.1";
enum KRUG_EXT = ".krug";

uint OPTIMIZATION_LEVEL = 0;
bool RELEASE_MODE = false;
string ARCH = arch_type();
string OPERATING_SYSTEM = os_name();
string OUT_NAME = "main";

static string os_name() {
	// this should cover most of the important-ish ones
	version (linux) {
		return "Linux";
	}
	else version (Windows) {
		return "Windows";
	}
	else version (OSX) {
		return "Mac OS X";
	}
	else version (POSIX) {
		return "POSIX";
	}
	else {
		return "Undefined";
	}
}

// this is not an exhaustive list
// of architectures!
static string arch_type() {
	version (X86) {
		return "x86";
	}
	else version (X86_64) {
		return "x86_64";
	}
	else {
		return "Undefined";
	}
}
