import QtQuick
import QtTest
import "../MacModel.js" as MacModel

TestCase {
    name: "MacModel"

    property var mini: { "id": "gustavos-mac-mini", "name": "Mac mini", "hostName": "Gustavo's Mac mini", "ip": "100.87.204.116",
        "user": "", "online": true, "lastSeen": 0, "os": "macos", "protocol": "vnc", "host": "100.87.204.116", "portOpen": true, "dnsName": "gustavos-mac-mini.mandrill-perch.ts.net", "ips": ["100.87.204.116", "fd7a:115c:a1e0::3501:cc8d"], "lanAddress": "10.0.0.35", "connection": "direct", "users": [], "lastUser": "",  "state": "online", "alwaysOn": true, "expected": true, "reasons": [] }
    property var pro: { "id": "gustavos-macbook-pro", "name": "MacBook Pro", "hostName": "MacBook Pro", "ip": "100.94.148.81",
        "user": "gustavo", "online": true, "lastSeen": 0, "os": "macos", "protocol": "vnc", "host": "100.94.148.81", "portOpen": false, "users": [{"name": "gustavo", "label": ""}], "lastUser": "", "state": "online", "alwaysOn": null, "expected": true, "reasons": ["power settings unknown"] }

    function test_parse() {
        compare(MacModel.parseResult("{\"macs\":[{\"id\":\"a\"}]}").macs.length, 1);
        compare(MacModel.parseResult("garbage").macs.length, 0);
        compare(MacModel.parseResult("{\"macs\":[],\"error\":\"x\"}").error, "x");
    }

    function test_stateAndBadge() {
        compare(MacModel.stateColor("online"), "#4ADE80");
        compare(MacModel.stateColor("sleeps"), "#F59E0B");
        compare(MacModel.stateColor("offline"), "#F87171");
        compare(MacModel.badge(mini).kind, "ok");
        compare(MacModel.badge(pro).kind, "unknown");
        var sleepy = { "alwaysOn": false, "expected": true, "reasons": ["sleeps after 10 min"] };
        compare(MacModel.badge(sleepy).kind, "warn");
        compare(MacModel.badge(sleepy).text, "⚠ not always on: sleeps after 10 min");
        compare(MacModel.badge({ "alwaysOn": false, "expected": false, "reasons": ["offline 3h"] }).kind, "none");
        compare(MacModel.badge(null).kind, "none");
    }

    function test_lastSeen() {
        compare(MacModel.lastSeenText(mini, 0), "online now");
        var off = { "online": false, "lastSeen": 1000 };
        compare(MacModel.lastSeenText(off, (1000 + 3 * 3600) * 1000), "last seen 3h ago");
        compare(MacModel.lastSeenText(off, (1000 + 10) * 1000), "last seen moments ago");
        compare(MacModel.lastSeenText(off, (1000 + 5 * 86400) * 1000), "last seen 5d ago");
        compare(MacModel.lastSeenText({ "online": false, "lastSeen": 0 }, 5), "never seen");
        compare(MacModel.ageText(600), "10 min");
    }

    function test_connect() {
        verify(MacModel.canConnect(mini));
        verify(!MacModel.canConnect(pro));
        verify(!MacModel.canConnect({ "online": false, "portOpen": true, "host": "1.2.3.4" }));
        verify(!MacModel.canConnect({ "online": true, "portOpen": true, "host": "" }));
        compare(MacModel.screenSharingNotice(pro), "Screen Sharing is off");
        compare(MacModel.screenSharingNotice(mini), "");
        compare(MacModel.screenSharingNotice({ "online": false, "portOpen": false }), "");
        compare(MacModel.screenSharingNotice({ "online": true, "portOpen": false, "protocol": "rdp" }), "Remote Desktop (RDP) is not answering");
        compare(MacModel.screenSharingNotice({ "online": true, "portOpen": false, "protocol": "ssh" }), "SSH is not answering");
        verify(MacModel.connectHint(pro).indexOf("Screen Sharing") >= 0);
        compare(MacModel.connectHint(mini), "");
        verify(MacModel.noClientMessage().indexOf("sudo pacman -S remmina") >= 0);
    }

    function test_nonMacBadge() {
        compare(MacModel.badge({ "trackPower": false, "alwaysOn": null, "expected": true }).kind, "none");
        compare(MacModel.badge({ "trackPower": false, "alwaysOn": false, "expected": true, "reasons": ["offline"] }).kind, "none");
    }

    function test_connectPlan() {
        var d = { "online": true, "portOpen": true, "host": "1.2.3.4", "users": [], "lastUser": "" };
        compare(MacModel.connectPlan(d).kind, "needUser");
        d.users = [{ "name": "a", "label": "" }];
        compare(MacModel.connectPlan(d).kind, "connect");
        compare(MacModel.connectPlan(d).user, "a");
        d.users = [{ "name": "a", "label": "" }, { "name": "b", "label": "Bee" }, { "name": "c", "label": "" }];
        compare(MacModel.connectPlan(d).kind, "choose");
        compare(MacModel.connectPlan(d).users[0].name, "a");
        d.lastUser = "c";
        compare(MacModel.orderedUsers(d).map(function (u) { return u.name; }).join(","), "c,a,b");
        compare(MacModel.userText(d.users[1]), "Bee (b)");
        compare(MacModel.connectPlan({ "online": false, "users": d.users }).kind, "none");
    }

    function test_commands() {
        compare(MacModel.sshCommand({ "host": "100.1.1.8" }, "root", 22).join(" "), "xdg-terminal-exec ssh -- root@100.1.1.8");
        compare(MacModel.sshCommand({ "host": "h" }, "u", 2222).join(" "), "xdg-terminal-exec ssh -p 2222 -- u@h");
        compare(MacModel.remminaCommand("/p/a.remmina").join(" "), "remmina -c /p/a.remmina");
        compare(MacModel.profileCommand("/plug", { "id": "mini" }, "gustavo").join(" "), "/plug/device-config profile mini gustavo");
        verify(MacModel.isProfilePath("/home/u/.local/share/x/mini-g.remmina"));
        verify(!MacModel.isProfilePath("relative.remmina"));
        verify(!MacModel.isProfilePath("/x\n/y.remmina"));
        verify(!MacModel.isProfilePath(""));
    }

    function test_clientCheck() {
        verify(MacModel.parseClientCheck("{\"ok\":true,\"message\":\"\"}").ok);
        var bad = MacModel.parseClientCheck("{\"ok\":false,\"message\":\"install: sudo pacman -S freerdp\"}");
        verify(!bad.ok);
        compare(bad.message, "install: sudo pacman -S freerdp");
        verify(!MacModel.parseClientCheck("").ok);
        verify(MacModel.parseClientCheck("garbage").message.indexOf("sudo pacman -S remmina libvncserver freerdp") >= 0);
        compare(MacModel.clientCheckCommand("/p", "rdp").join(" "), "/p/device-config check-client rdp");
    }

    function test_addressInfo() {
        var info = MacModel.addressInfo(mini);
        compare(info.dns, "gustavos-mac-mini.mandrill-perch.ts.net");
        compare(info.ip, "100.87.204.116");
        compare(info.lan, "10.0.0.35");
        compare(info.connection, "direct");
        var relayed = MacModel.addressInfo({ "dnsName": "a.ts.net", "ip": "100.1.1.2", "ips": ["100.1.1.2"], "lanAddress": "", "connection": "relayed via mia" });
        compare(relayed.lan, "");
        compare(relayed.connection, "relayed via mia");
        // hostile values never reach the screen or the clipboard
        var evil = MacModel.addressInfo({ "dnsName": "a b;rm -rf", "ip": "$(id)", "ips": ["x;y"], "lanAddress": "1.2.3.4;x", "connection": "direct\nboom" });
        compare(evil.dns, "");
        compare(evil.ip, "");
        compare(evil.lan, "");
        compare(evil.connection, "");
        compare(MacModel.safeAddress("fd7a:115c:a1e0::3501:cc8d"), "fd7a:115c:a1e0::3501:cc8d");
        compare(MacModel.safeAddress("999.1.1.1;x"), "");
        compare(MacModel.addressInfo(null).ip, "");
    }

    function test_windowMatch() {
        verify(MacModel.windowMatches(mini, "org.remmina.Remmina", "gustavos-mac-mini - Remmina"));
        verify(MacModel.windowMatches(mini, "remmina", "vnc://100.87.204.116"));
        verify(MacModel.windowMatches(mini, "org.kde.krdc", "Mac mini - KRDC"));
        verify(!MacModel.windowMatches(mini, "kitty", "gustavos-mac-mini"));
        verify(!MacModel.windowMatches(mini, "remmina", "something else"));
        verify(!MacModel.windowMatches(pro, "remmina", "gustavos-mac-mini"));
        verify(MacModel.anyMacMatches([pro, mini], "remmina", "100.87.204.116"));
        verify(!MacModel.anyMacMatches([], "remmina", "100.87.204.116"));
    }
}
