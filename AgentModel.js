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
    if (status === "ended")
        return "ended";
    return "waiting";
}

// Group heading for the sidebar: working, waiting (touched in the last day), older.
function sessionGroup(session, nowMs) {
    var state = sessionState(session);
    if (state === "ended")
        return 3;
    if (state === "working" || state === "shell")
        return 0;
    var at = Number(session.statusAt) || 0;
    return nowMs - at < 86400000 ? 1 : 2;
}

var GROUP_TITLES = ["Working", "Waiting for you", "Older", "Not running", "Archived"];

function sortedSessions(results, nowMs) {
    var list = results && results.sessions ? results.sessions.slice() : [];
    list.sort(function (a, b) {
        var ga = a.archived ? 4 : sessionGroup(a, nowMs), gb = b.archived ? 4 : sessionGroup(b, nowMs);
        if (ga !== gb)
            return ga - gb;
        return (Number(b.statusAt) || 0) - (Number(a.statusAt) || 0);
    });
    return list;
}

// Flat rows for a list: {header: "Working"} entries between {session: {...}} rows.
// options: {showOlder, showEnded, showArchived}, each on unless set to false
// (showArchived is off unless true). Archived sessions sort into their own group.
function sessionRows(results, nowMs, options) {
    var showOlder = options === false ? false : !(options && options.showOlder === false);
    var showEnded = !(options && typeof options === "object" && options.showEnded === false);
    var showArchived = !!(options && typeof options === "object" && options.showArchived === true);
    var rows = [];
    var last = -1;
    var list = sortedSessions(results, nowMs);
    for (var i = 0; i < list.length; i++) {
        var group = sessionGroup(list[i], nowMs);
        if (list[i].archived && !showArchived)
            continue;
        if (list[i].archived)
            group = 4;
        if ((group === 2 && !showOlder) || (group === 3 && !showEnded))
            continue;
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

// Where a session's work stands in git: "unknown" (not a repo), "dirty"
// (uncommitted changes), "unmerged" (commits main lacks) or "clean" (all on main).
// Both flags can hold at once; the chips list every one that applies.
function gitChips(git) {
    if (!git || git.dirty === undefined)
        return [];
    var chips = [];
    if (git.dirty > 0)
        chips.push({ kind: "dirty", text: "✎ " + git.dirty + " uncommitted" });
    if (git.ahead > 0)
        chips.push({ kind: "unmerged", text: "↑ " + git.ahead + " not on " + String(git.base || "main").replace(/^origin\//, "") });
    if (!chips.length && git.base)
        chips.push({ kind: "clean", text: "✓ all on " + String(git.base).replace(/^origin\//, "") });
    return chips;
}

// What a session is about: its own name when the person or Claude gave it one,
// else Claude Code's generated title, else the derived name.
function sessionTitle(session) {
    if (!session)
        return "";
    var title = String(session.title || "");
    if (String(session.nameSource || "") === "derived" && title)
        return title;
    return String(session.name || title || "");
}

// Claude Code's own recap ("Goal: … Next: …") when it has written one, else the
// generated title when that adds something to the shown one, else "".
function sessionGoal(session) {
    var recap = String(session && session.recap || "");
    if (recap)
        return recap.replace(/^Goal:\s*/i, "");
    var title = String(session && session.title || "");
    return title && title !== sessionTitle(session) ? title : "";
}

// The project a session works in: "kboom" in its main checkout, "kboom › linux-edge"
// in a worktree or subfolder of another repo, the folder name outside git.
function projectLabel(cwd, git, home) {
    var folder = folderName(cwd, home);
    var repo = git && git.repo ? String(git.repo) : "";
    if (!folder)
        return repo;
    return repo && repo !== folder ? repo + " › " + folder : folder;
}

// "6.4 GB", "820 MB".
function bytesText(bytes) {
    var n = Number(bytes);
    if (!isFinite(n) || n <= 0)
        return "";
    if (n >= 1e9)
        return (n / 1e9).toFixed(n >= 1e10 ? 0 : 1) + " GB";
    return Math.max(1, Math.round(n / 1e6)) + " MB";
}

// Chips under a session: git state, plus the worktree's disk use.
function sessionChips(session) {
    if (!session)
        return [];
    var chips = gitChips(session.git);
    var size = bytesText(session.sizeBytes);
    if (size && session.git && session.git.linked && session.cwdExists !== false)
        chips.push({ kind: "size", text: "▤ " + size + " worktree" });
    var usage = usageChip(session);
    if (usage)
        chips.push(usage);
    return chips;
}

// Can the session's worktree be freed right now? Needs a linked worktree with no
// uncommitted changes, and nothing else running in it; a live session may only be
// idle (freeing ends it).
function canFreeWorktree(session) {
    if (!session || !session.git || !session.git.linked || session.git.dirty !== 0 || !session.cwdExists)
        return false;
    if (session.live)
        return session.liveHere === 1 && sessionState(session) === "waiting";
    return !session.liveHere;
}

function freeSummary(session) {
    if (!session || !session.git)
        return "";
    var parts = ["Removes the worktree folder"];
    var size = bytesText(session.sizeBytes);
    if (size)
        parts[0] += " (" + size + ")";
    var branch = String(session.branch || "");
    var ahead = Number(session.git.ahead) || 0;
    parts.push(ahead > 0
        ? "Branch " + branch + " keeps its " + ahead + (ahead === 1 ? " commit" : " commits")
        : "Branch " + branch + " is kept");
    if (session.live)
        parts.push("ends this idle session");
    return parts.join(". ") + ".";
}

// ---- Activity monitor ----

// 100 means one core fully busy: "34% CPU" below that, "1.4 cores" above.
function cpuText(percentOfCore) {
    var n = Number(percentOfCore);
    if (!isFinite(n) || n < 0)
        return "";
    return n >= 100 ? (n / 100).toFixed(1) + " cores" : Math.round(n) + "% CPU";
}

function memText(bytes) {
    var n = Number(bytes);
    if (!isFinite(n) || n <= 0)
        return "";
    return n >= 1e9 ? (n / 1e9).toFixed(1) + " GB" : Math.max(1, Math.round(n / 1e6)) + " MB";
}

// "⚙ 1.4 cores · 2.1 GB" for a running session's processes; "hot" at one core or more.
function usageChip(session) {
    var usage = session && session.live ? session.usage : null;
    if (!usage || !usage.rssBytes)
        return null;
    var parts = [cpuText(usage.cpu), memText(usage.rssBytes)].filter(function (x) { return x; });
    return { kind: usage.cpu >= 100 ? "hot" : "usage", text: "⚙ " + parts.join(" · ") };
}

// What all running AI sessions use together: {cpu, rssBytes, count}.
function sessionTotals(results) {
    var total = { cpu: 0, rssBytes: 0, count: 0 };
    var list = results && results.sessions ? results.sessions : [];
    for (var i = 0; i < list.length; i++) {
        var usage = list[i].live ? list[i].usage : null;
        if (!usage)
            continue;
        total.cpu += Number(usage.cpu) || 0;
        total.rssBytes += Number(usage.rssBytes) || 0;
        total.count++;
    }
    return total;
}

// 0..1 for a bar; null-safe.
function fraction(part, whole) {
    var a = Number(part), b = Number(whole);
    return isFinite(a) && isFinite(b) && b > 0 ? Math.max(0, Math.min(1, a / b)) : 0;
}
