.pragma library

// Macs come from ./mac-status. This file turns its facts into what the cards say.

var CLIENT_CLASSES = ["remmina", "vncviewer", "krdc", "tigervnc", "xtigervncviewer"];
var INSTALL_LINE = "sudo pacman -S remmina libvncserver freerdp";

function parseResult(text) {
    try {
        var value = JSON.parse(String(text || ""));
        var list = value && Array.isArray(value.devices) ? value.devices : (value && Array.isArray(value.macs) ? value.macs : null);
        if (!list)
            return { macs: [], devices: [], error: String((value && value.error) || ""), warnings: [] };
        return { macs: list, devices: list, error: String(value.error || ""), warnings: value.warnings || [] };
    } catch (error) {
        return { macs: [], devices: [], error: "", warnings: [] };
    }
}

// green online, amber sleeps, red offline
function stateColor(state) {
    return state === "online" ? "#4ADE80" : (state === "sleeps" ? "#F59E0B" : "#F87171");
}

function stateText(mac) {
    if (!mac)
        return "";
    return mac.state === "online" ? "Online" : (mac.state === "sleeps" ? "Asleep or sleeps" : "Offline");
}

function ageText(seconds) {
    var s = Math.max(0, Math.floor(seconds));
    if (s < 90)
        return "moments";
    if (s < 3600)
        return Math.floor(s / 60) + " min";
    if (s < 86400)
        return Math.floor(s / 3600) + "h";
    return Math.floor(s / 86400) + "d";
}

function lastSeenText(mac, nowMs) {
    if (!mac)
        return "";
    if (mac.online)
        return "online now";
    if (!mac.lastSeen)
        return "never seen";
    return "last seen " + ageText(nowMs / 1000 - mac.lastSeen) + " ago";
}

// {kind: ok|warn|unknown|none, text}. Only macOS devices have a power verdict,
// and a device not expected to stay on never warns.
function badge(mac) {
    if (!mac || mac.trackPower === false)
        return { kind: "none", text: "" };
    if (mac.alwaysOn === true)
        return { kind: "ok", text: "✓ always on" };
    var reasons = mac.reasons && mac.reasons.length ? mac.reasons : [];
    if (mac.expected === false)
        return { kind: "none", text: "" };
    if (mac.alwaysOn === false)
        return { kind: "warn", text: "⚠ not always on" + (reasons.length ? ": " + reasons[0] : "") };
    return { kind: "unknown", text: "always on unknown" };
}

function badgeColor(kind) {
    return kind === "ok" ? "#4ADE80" : (kind === "warn" ? "#F59E0B" : "#9CA3AF");
}

var PROTOCOL_NAMES = { vnc: "VNC", rdp: "RDP", ssh: "SSH" };

function osGlyph(mac) {
    return mac && mac.os === "windows" ? "🪟" : (mac && mac.os === "linux" ? "🐧" : "🖥");
}

// Says why Connect is unavailable while the device is up.
function screenSharingNotice(mac) {
    if (!mac || !mac.online || mac.portOpen === true)
        return "";
    if (mac.protocol === "rdp")
        return "Remote Desktop (RDP) is not answering";
    if (mac.protocol === "ssh")
        return "SSH is not answering";
    return mac.os === "macos" ? "Screen Sharing is off" : "VNC is not answering";
}

function canConnect(mac) {
    return Boolean(mac) && mac.online === true && mac.portOpen === true && Boolean(mac.host);
}

function connectHint(mac) {
    if (!mac)
        return "";
    if (!mac.online)
        return "Offline. It must wake before you can connect.";
    if (!mac.portOpen)
        return mac.os === "macos" && mac.protocol === "vnc"
            ? "Turn on System Settings > General > Sharing > Screen Sharing on this Mac."
            : "Nothing is listening on the " + (PROTOCOL_NAMES[mac.protocol] || "") + " port.";
    return "";
}

// Users with the last used one first; [{name, label}].
function orderedUsers(device) {
    var users = (device && device.users) ? device.users.slice() : [];
    var last = device ? device.lastUser : "";
    var first = users.filter(function (u) { return u.name === last; });
    return first.concat(users.filter(function (u) { return u.name !== last; }));
}

function userText(user) {
    return user.label ? user.label + " (" + user.name + ")" : user.name;
}

// What the Connect button does: {kind: none|needUser|connect|choose, user, users}
function connectPlan(device) {
    var users = orderedUsers(device);
    if (!canConnect(device))
        return { kind: "none", user: "", users: users };
    if (users.length === 0)
        return { kind: "needUser", user: "", users: users };
    if (users.length === 1)
        return { kind: "connect", user: users[0].name, users: users };
    return { kind: "choose", user: "", users: users };
}

function needUserMessage(device) {
    return "Add a user for " + (device ? device.name : "this device") + " in the gear (Devices > Configure) before connecting.";
}

// ssh opens a terminal; argv only, no shell. "--" keeps the target from
// being read as an option.
function sshCommand(device, user, port) {
    var argv = ["xdg-terminal-exec", "ssh"];
    if (port && port !== 22)
        argv.push("-p", String(port));
    argv.push("--", user + "@" + device.host);
    return argv;
}

function remminaCommand(profilePath) {
    return ["remmina", "-c", profilePath];
}

function profileCommand(pluginDir, device, user) {
    return [pluginDir + "/device-config", "profile", device.id, user];
}

// Reply of `device-config check-client`: {ok, message}. Anything unreadable
// counts as a failure so a broken helper never launches a half-working client.
function parseClientCheck(text) {
    try {
        var value = JSON.parse(String(text || ""));
        if (value && value.ok === true)
            return { ok: true, message: "" };
        return { ok: false, message: String((value && value.message) || noClientMessage()) };
    } catch (error) {
        return { ok: false, message: noClientMessage() };
    }
}

function clientCheckCommand(pluginDir, protocol) {
    return [pluginDir + "/device-config", "check-client", protocol];
}

function isProfilePath(text) {
    return /^\/[^\n]*\.remmina$/.test(String(text || ""));
}

// Shown and copied only when they pass the same address checks as the config.
var IPV4_RE = /^(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)$/;
var IPV6_RE = /^(?=.*:)[0-9A-Fa-f:.]{2,45}$/;
var HOST_RE = /^(?=.{1,253}$)[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$/;

function safeAddress(text) {
    var value = String(text === undefined || text === null ? "" : text).trim();
    return value !== "" && (IPV4_RE.test(value) || IPV6_RE.test(value) || HOST_RE.test(value)) ? value : "";
}

function tailscaleV4(device) {
    var ips = (device && device.ips) || [];
    for (var i = 0; i < ips.length; i++)
        if (IPV4_RE.test(String(ips[i])))
            return String(ips[i]);
    return safeAddress(device && device.ip);
}

// {dns, ip, lan, connection} for the card and the editor; each already safe.
function addressInfo(device) {
    if (!device)
        return { dns: "", ip: "", lan: "", connection: "" };
    var connection = String(device.connection || "");
    return {
        dns: safeAddress(device.dnsName),
        ip: tailscaleV4(device),
        lan: connection === "direct" ? safeAddress(device.lanAddress) : "",
        connection: /^[A-Za-z0-9 ._-]{0,60}$/.test(connection) ? connection : ""
    };
}

function noClientMessage() {
    return "Remmina is not installed. Install it with: " + INSTALL_LINE;
}

function isClientClass(appId) {
    var id = String(appId || "").toLowerCase();
    for (var i = 0; i < CLIENT_CLASSES.length; i++)
        if (id.indexOf(CLIENT_CLASSES[i]) !== -1)
            return true;
    return false;
}

// A remote-desktop window belongs to a Mac when its title or class names the
// Mac (display name, host name, DNS label) or its Tailscale IP.
function windowMatches(mac, appId, title) {
    if (!mac || !isClientClass(appId))
        return false;
    var hay = (String(title || "") + " " + String(appId || "")).toLowerCase();
    var needles = [mac.ip, mac.id, mac.name, mac.hostName];
    for (var i = 0; i < needles.length; i++) {
        var n = String(needles[i] || "").toLowerCase();
        if (n.length >= 3 && hay.indexOf(n) !== -1)
            return true;
    }
    return false;
}

function anyMacMatches(macs, appId, title) {
    for (var i = 0; i < (macs || []).length; i++)
        if (windowMatches(macs[i], appId, title))
            return true;
    return false;
}

// Order devices for the row: "recent" puts the most recently connected first (never
// connected ones after, online before offline), "az" sorts by name. Returns a new list.
function sortDevices(list, mode) {
    var items = (list || []).slice();
    var name = function (d) { return String(d.name || d.hostname || d.id || "").toLowerCase(); };
    items.sort(function (a, b) {
        if (mode !== "az") {
            var ua = Number(a.lastUsedAt) || 0, ub = Number(b.lastUsedAt) || 0;
            if (ua !== ub)
                return ub - ua;
            var oa = a.state === "online" ? 1 : 0, ob = b.state === "online" ? 1 : 0;
            if (oa !== ob)
                return ob - oa;
        }
        var na = name(a), nb = name(b);
        return na < nb ? -1 : (na > nb ? 1 : 0);
    });
    return items;
}
