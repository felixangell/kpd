module colour;

static string RED = "\u001b[31m";
static string GREEN = "\u001b[32m";
static string YELLOW = "\u001b[33m";
static string BLUE = "\u001b[34m";
static string MAGENTA = "\u001b[35m";
static string CYAN = "\u001b[36m";
static string BOLD = "\u001b[01m";
static string RESET = "\u001b[0m";

bool NO_COLOURS = false;

static string Warn(string str)
{
    return Colourize(YELLOW, str);
}

static string Bold(string str)
{
    return Colourize(BOLD, str);
}

static string Err(string str)
{
    return Colourize(RED, str);
}

static string Colourize(string col, string str)
{
    if (NO_COLOURS)
    {
        return str;
    }
    return col ~ str ~ RESET;
}
