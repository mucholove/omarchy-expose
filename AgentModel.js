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
    var windows = results && results.windows ? results.windows : null;
    var entry = windows ? windows[String(pid)] : null;
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
function shortPath(path, home, full) {
    var text = String(path || "");
    if (!text || text.indexOf("/proc/") === 0)
        return "";
    var base = String(home || "");
    if (base && (text === base || text.indexOf(base + "/") === 0))
        text = "~" + text.substring(base.length);
    var parts = text.split("/");
    if (!full && parts.length > 3)
        text = "…/" + parts[parts.length - 1];
    return text;
}

// Last folder of a path: "/home/me/Work/kboom" -> "kboom", home -> "~".
function folderName(path, home) {
    var text = String(path || "");
    if (!text || text.indexOf("/proc/") === 0)
        return "";
    if (home && text === String(home))
        return "~";
    var parts = text.split("/");
    return parts[parts.length - 1] || "/";
}

// "3d 4h", "2h 5m", "7m", "just now".
function durationText(startedSeconds, nowSeconds) {
    var span = Number(nowSeconds) - Number(startedSeconds);
    if (!isFinite(span) || Number(startedSeconds) <= 0 || span < 0)
        return "";
    var minutes = Math.floor(span / 60);
    var hours = Math.floor(minutes / 60);
    var days = Math.floor(hours / 24);
    if (days > 0)
        return days + "d " + (hours % 24) + "h";
    if (hours > 0)
        return hours + "h " + (minutes % 60) + "m";
    return minutes > 0 ? minutes + "m" : "just now";
}

// ---- Claude Code sessions (from ~/.claude/sessions via agent-of-windows) ----

// "working", "waiting" (finished its turn, waits for you), "shell" or "idle".
function sessionState(session) {
    var status = String((session && session.status) || "");
    if (status === "busy")
        return "working";
    if (status === "shell")
        return "shell";
    return "waiting";
}

// Group heading for the sidebar: working, waiting (touched in the last day), older.
function sessionGroup(session, nowMs) {
    var state = sessionState(session);
    if (state === "working" || state === "shell")
        return 0;
    var at = Number(session.statusAt) || 0;
    return nowMs - at < 86400000 ? 1 : 2;
}

var GROUP_TITLES = ["Working", "Waiting for you", "Older"];

function sortedSessions(results, nowMs) {
    var list = results && results.sessions ? results.sessions.slice() : [];
    list.sort(function (a, b) {
        var ga = sessionGroup(a, nowMs), gb = sessionGroup(b, nowMs);
        if (ga !== gb)
            return ga - gb;
        return (Number(b.statusAt) || 0) - (Number(a.statusAt) || 0);
    });
    return list;
}

// Flat rows for a list: {header: "Working"} entries between {session: {...}} rows.
function sessionRows(results, nowMs) {
    var rows = [];
    var last = -1;
    var list = sortedSessions(results, nowMs);
    for (var i = 0; i < list.length; i++) {
        var group = sessionGroup(list[i], nowMs);
        if (group !== last) {
            rows.push({ header: GROUP_TITLES[group], session: null });
            last = group;
        }
        rows.push({ header: "", session: list[i] });
    }
    return rows;
}

// "124k", "1.2M", "850".
function tokensText(count) {
    var n = Number(count);
    if (!isFinite(n) || n <= 0)
        return "";
    if (n >= 1000000)
        return (n / 1000000).toFixed(1) + "M";
    if (n >= 1000)
        return Math.round(n / 1000) + "k";
    return String(n);
}

// "claude-opus-5-5" -> "Opus 5.5".
function modelLabel(model) {
    var match = String(model || "").match(/^claude-([a-z]+)-(\d+)(?:-(\d+))?/);
    if (!match)
        return String(model || "");
    var family = match[1].charAt(0).toUpperCase() + match[1].substring(1);
    return family + " " + match[2] + (match[3] ? "." + match[3] : "");
}

// Age text for a millisecond timestamp, "" when unknown.
function ageText(timestampMs, nowMs) {
    return durationText(Number(timestampMs) / 1000, Number(nowMs) / 1000);
}
