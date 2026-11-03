.pragma library

// Macs come from ./mac-status. This file turns its facts into what the cards say.

var CLIENT_CLASSES = ["remmina", "vncviewer", "krdc", "tigervnc", "xtigervncviewer"];
var INSTALL_LINE = "sudo pacman -S remmina";

function parseResult(text) {
    try {
        var value = JSON.parse(String(text || ""));
        return value && Array.isArray(value.macs) ? value : { macs: [], error: String((value && value.error) || "") };
    } catch (error) {
        return { macs: [], error: "" };
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

// {kind: ok|warn|unknown|none, text}. A Mac not expected to stay on never warns.
function badge(mac) {
    if (!mac)
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

function screenSharingNotice(mac) {
    if (!mac || !mac.online || mac.screenSharing)
        return "";
    return "Screen Sharing is off";
}

function canConnect(mac) {
    return Boolean(mac) && mac.online === true && mac.screenSharing === true;
}

function connectHint(mac) {
    if (!mac)
        return "";
    if (!mac.online)
        return "Offline. It must wake before you can connect.";
    if (!mac.screenSharing)
        return "Turn on System Settings > General > Sharing > Screen Sharing on this Mac.";
    return "";
}

// First installed client wins; Remmina's VNC plugin speaks Apple's ARD login.
function clientCommand(available, mac) {
    var have = available || [];
    var target = (mac.user ? mac.user + "@" : "") + mac.ip;
    if (have.indexOf("remmina") !== -1)
        return ["remmina", "-c", "vnc://" + target];
    if (have.indexOf("vncviewer") !== -1)
        return ["vncviewer", mac.ip];
    if (have.indexOf("krdc") !== -1)
        return ["krdc", "vnc://" + mac.ip];
    return [];
}

function noClientMessage() {
    return "No remote desktop client found. Install one with: " + INSTALL_LINE;
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
