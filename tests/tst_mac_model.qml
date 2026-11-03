import QtQuick
import QtTest
import "../MacModel.js" as MacModel

TestCase {
    name: "MacModel"

    property var mini: { "id": "gustavos-mac-mini", "name": "Mac mini", "hostName": "Gustavo's Mac mini", "ip": "100.87.204.116",
        "user": "", "online": true, "lastSeen": 0, "screenSharing": true, "state": "online", "alwaysOn": true, "expected": true, "reasons": [] }
    property var pro: { "id": "gustavos-macbook-pro", "name": "MacBook Pro", "hostName": "MacBook Pro", "ip": "100.94.148.81",
        "user": "gustavo", "online": true, "lastSeen": 0, "screenSharing": false, "state": "online", "alwaysOn": null, "expected": true, "reasons": ["power settings unknown"] }

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
        verify(!MacModel.canConnect({ "online": false, "screenSharing": true }));
        compare(MacModel.screenSharingNotice(pro), "Screen Sharing is off");
        compare(MacModel.screenSharingNotice(mini), "");
        compare(MacModel.screenSharingNotice({ "online": false, "screenSharing": false }), "");
        verify(MacModel.connectHint(pro).indexOf("Screen Sharing") >= 0);
        compare(MacModel.connectHint(mini), "");
    }

    function test_clientCommand() {
        compare(MacModel.clientCommand(["krdc", "remmina"], mini).join(" "), "remmina -c vnc://100.87.204.116");
        compare(MacModel.clientCommand(["remmina"], pro).join(" "), "remmina -c vnc://gustavo@100.94.148.81");
        compare(MacModel.clientCommand(["krdc", "vncviewer"], mini).join(" "), "vncviewer 100.87.204.116");
        compare(MacModel.clientCommand(["krdc"], mini).join(" "), "krdc vnc://100.87.204.116");
        compare(MacModel.clientCommand([], mini).length, 0);
        verify(MacModel.noClientMessage().indexOf("sudo pacman -S remmina") >= 0);
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
