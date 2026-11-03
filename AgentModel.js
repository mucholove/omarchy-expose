.pragma library

// Agent detection results come from ./agent-of-windows, keyed by window pid.
// Titles follow Claude Code: "✳ " while it waits, a spinner while it works.

var TERMINAL_CLASSES = ["kitty", "alacritty", "org.omarchy.agent", "foot", "ghostty",
    "com.mitchellh.ghostty", "wezterm", "org.wezfurlong.wezterm", "xterm", "konsole"];

var AGENT_LABELS = {
    "claude": "Claude Code",
    "codex": "Codex",
    "opencode": "opencode",
    "gemini": "Gemini CLI",
    "aider": "aider",
    "amp": "Amp",
    "cursor-agent": "Cursor Agent"
};

var SPINNERS = "◐◓◑◒◴◷◶◵⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏⠂⠐⠒⠲⠴⠤⠄·✢✳✶✻✽";

function parseResult(text) {
    try {
        var value = JSON.parse(String(text || ""));
        return value && typeof value === "object" ? value : {};
    } catch (error) {
        return {};
    }
}

function infoFor(results, pid) {
    var entry = results ? results[String(pid)] : null;
    return entry && typeof entry === "object" ? entry : { agent: "", cwd: "" };
}

function isTerminalClass(appId) {
    return TERMINAL_CLASSES.indexOf(String(appId || "").toLowerCase()) !== -1;
}

function labelFor(agent) {
    return AGENT_LABELS[agent] || "";
}

// "waiting", "working" or "" (the title says nothing).
function stateFromTitle(title) {
    var text = String(title || "");
    if (!text)
        return "";
    var first = text.charAt(0);
    if (first === "✳")
        return "waiting";
    if ("◐◓◑◒◴◷◶◵⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏⠂⠐⠒⠲⠤⠄✢✶✻✽".indexOf(first) !== -1)
        return "working";
    return "";
}

// Drops the leading status glyph and the space after it.
function cleanTitle(title) {
    var text = String(title || "");
    if (text.length > 1 && SPINNERS.indexOf(text.charAt(0)) !== -1 && /\s/.test(text.charAt(1)))
        return text.substring(2);
    return text;
}

// "/home/me/Work/x" -> "~/Work/x"; deeper paths keep only the last folder.
function shortPath(path, home) {
    var text = String(path || "");
    if (!text || text.indexOf("/proc/") === 0)
        return "";
    var base = String(home || "");
    if (base && (text === base || text.indexOf(base + "/") === 0))
        text = "~" + text.substring(base.length);
    var parts = text.split("/");
    if (parts.length > 3)
        text = "…/" + parts[parts.length - 1];
    return text;
}
