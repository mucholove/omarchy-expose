.pragma library

// Editing and validation rules for the device configuration panel. They mirror
// ./devices_core.py so mistakes show immediately; device-config remains the
// authority and re-validates everything on save.

var PROTOCOLS = ["vnc", "rdp", "ssh"];
var PROTOCOL_LABELS = { vnc: "VNC", rdp: "RDP", ssh: "SSH" };
var DEFAULT_PORTS = { vnc: 5900, rdp: 3389, ssh: 22 };

var ID_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;
var USER_RE = /^[A-Za-z0-9._][A-Za-z0-9._-]{0,63}$/;
var HOST_RE = /^(?=.{1,253}$)[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$/;
var IPV4_RE = /^(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)$/;
var IPV6_RE = /^(?=.*:)[0-9A-Fa-f:.]{2,45}$/;

function protocolLabel(protocol) {
    return PROTOCOL_LABELS[protocol] || "";
}

function defaultPort(protocol) {
    return DEFAULT_PORTS[protocol] || 0;
}

function hasControlChars(text, allowNewline) {
    for (var i = 0; i < text.length; i++) {
        var c = text.charCodeAt(i);
        if ((c < 32 && !(allowNewline && c === 10)) || (c >= 127 && c < 160))
            return true;
    }
    return false;
}

// "" for a valid IP or host name, else the problem. Empty input is valid.
function addressProblem(text) {
    var value = String(text === undefined || text === null ? "" : text).trim();
    if (value === "")
        return "";
    if (value.length > 253 || value.indexOf("%") !== -1)
        return "not a valid IP address or host name";
    if (IPV4_RE.test(value) || IPV6_RE.test(value) || HOST_RE.test(value))
        return "";
    return "not a valid IP address or host name";
}

// The text if it is safe to show or copy, else "".
function safeAddress(text) {
    var value = String(text === undefined || text === null ? "" : text).trim();
    return value !== "" && addressProblem(value) === "" ? value : "";
}

function userProblem(name) {
    return USER_RE.test(String(name || "")) ? "" : "user name may only use letters, digits . _ - (max 64)";
}

// Port text -> {value: int|null, error: string}
function parsePort(text) {
    var s = String(text === undefined || text === null ? "" : text).trim();
    if (s === "")
        return { value: null, error: "" };
    if (!/^\d{1,5}$/.test(s) || parseInt(s, 10) < 1 || parseInt(s, 10) > 65535)
        return { value: null, error: "port must be a whole number from 1 to 65535" };
    return { value: parseInt(s, 10), error: "" };
}

// Editor draft -> {entry, errors}. draft fields are all strings/bools as typed;
// users is [{name, label}]. errors are human-readable and never dropped.
function buildEntry(draft) {
    var errors = [];
    var label = (draft.name || draft.id || "device");
    var entry = {
        id: String(draft.id || ""),
        match: String(draft.match || ""),
        name: String(draft.name || "").trim(),
        address: String(draft.address || "").trim(),
        protocol: String(draft.protocol || "vnc"),
        port: null,
        alwaysOn: draft.alwaysOn !== false,
        hidden: draft.hidden === true,
        notes: String(draft.notes || ""),
        users: []
    };
    if (!ID_RE.test(entry.id))
        errors.push(label + ": invalid id");
    if (entry.name.length > 64)
        errors.push(label + ": name is longer than 64 characters");
    if (hasControlChars(entry.name, false))
        errors.push(label + ": name contains control characters");
    var addr = addressProblem(entry.address);
    if (addr)
        errors.push(label + ": address " + addr);
    if (PROTOCOLS.indexOf(entry.protocol) === -1)
        errors.push(label + ": choose VNC, RDP or SSH");
    var port = parsePort(draft.port);
    if (port.error)
        errors.push(label + ": " + port.error);
    entry.port = port.value;
    if (entry.notes.length > 500)
        errors.push(label + ": notes are longer than 500 characters");
    if (hasControlChars(entry.notes, true))
        errors.push(label + ": notes contain control characters");
    var seen = {};
    var users = draft.users || [];
    for (var i = 0; i < users.length; i++) {
        var name = String(users[i].name || "").trim();
        var ulabel = String(users[i].label || "").trim();
        if (name === "" && ulabel === "")
            continue;
        var problem = userProblem(name);
        if (problem) {
            errors.push(label + ": user " + (i + 1) + " " + problem);
            continue;
        }
        if (seen[name]) {
            errors.push(label + ": user " + name + " is listed twice");
            continue;
        }
        if (ulabel.length > 64 || hasControlChars(ulabel, false)) {
            errors.push(label + ": label for " + name + " is too long or has control characters");
            continue;
        }
        seen[name] = true;
        entry.users.push({ name: name, label: ulabel });
    }
    if (entry.users.length > 16)
        errors.push(label + ": at most 16 users");
    return { entry: entry, errors: errors };
}

// All drafts -> {payload (JSON text for `device-config save`), errors}.
function buildPayload(drafts) {
    var entries = [], errors = [], ids = {};
    for (var i = 0; i < drafts.length; i++) {
        var built = buildEntry(drafts[i]);
        errors = errors.concat(built.errors);
        if (ids[built.entry.id])
            errors.push((built.entry.name || built.entry.id) + ": id " + built.entry.id + " used twice");
        ids[built.entry.id] = true;
        entries.push(built.entry);
    }
    return { payload: JSON.stringify({ devices: entries }), errors: errors };
}

// Id for a manually added device: lower-case slug of its name, made unique.
function manualId(name, existingIds) {
    var base = String(name || "").toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^[-._]+|[-._]+$/g, "").slice(0, 56);
    if (!base)
        base = "device";
    var id = base, n = 2;
    while (existingIds.indexOf(id) !== -1)
        id = base + "-" + (n++);
    return id;
}

function parseSaveReply(text) {
    try {
        var reply = JSON.parse(String(text || ""));
        if (reply && reply.ok === true)
            return { ok: true, errors: [] };
        return { ok: false, errors: reply && reply.errors && reply.errors.length ? reply.errors.map(String) : ["Could not save."] };
    } catch (error) {
        return { ok: false, errors: ["Could not save: no valid reply from device-config."] };
    }
}

// What a key does while the panel is open. Everything except Escape is left
// for the focused field: typing must never reach the window-search filter.
function keyAction(key, escapeKey) {
    return key === escapeKey ? "close" : "pass";
}
