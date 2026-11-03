import QtQuick
import Quickshell
import "DeviceModel.js" as DeviceModel
import qs.Commons
import qs.Commons as Commons

// DevicePanel and MacRow against the real shell theme, with a mock controller.
ShellRoot {
    id: test
    property int phase: 0

    QtObject {
        id: controller
        property bool macLoaded: true
        property bool devicesOpen: true
        property bool opened: true
        property string pluginDir: "/nonexistent"
        property real macNowMs: Date.now()
        property int modelRevision: 0
        property int closed: 0
        property var copied: []
        property var macResults: ({ error: "", warnings: [], devices: [
            { id: "mini", name: "Mac mini", hostName: "Mac mini", os: "macos", source: "tailscale", ip: "100.1.1.1",
              ips: ["100.1.1.1"], dnsName: "mini.ts.net", lanAddress: "10.0.0.35", connection: "direct", host: "100.1.1.1",
              protocol: "vnc", port: 5900, portOpen: true, online: true, lastSeen: 0, state: "online", alwaysOn: true,
              expected: true, trackPower: true, hidden: false, reasons: [], lastUser: "guest",
              users: [{ name: "gustavo", label: "Gustavo" }, { name: "guest", label: "" }],
              config: { id: "mini", match: "mini", name: "", address: "", protocol: "vnc", port: null, alwaysOn: true,
                        hidden: false, notes: "", users: [{ name: "gustavo", label: "Gustavo" }, { name: "guest", label: "" }] } },
            { id: "box", name: "box", hostName: "box", os: "linux", source: "tailscale", ip: "100.1.1.2", ips: ["100.1.1.2"],
              dnsName: "box.ts.net", lanAddress: "", connection: "relayed via fra", host: "100.1.1.2", protocol: "ssh",
              port: 22, portOpen: false, online: true, lastSeen: 0, state: "online", alwaysOn: null, expected: true,
              trackPower: false, hidden: false, reasons: [], lastUser: "", users: [],
              config: { id: "box", match: "box", name: "", address: "", protocol: "ssh", port: null, alwaysOn: true,
                        hidden: false, notes: "", users: [] } }
        ] })
        readonly property var macList: macResults.devices
        readonly property string deviceSort: "recent"
        function setDeviceSort(value) {}
        function closeDevices() { closed++; }
        function devicesSaved() {}
        function openDevices() {}
        function copyAddress(text) { copied = copied.concat([text]); }
        function macWindowFor(mac) { return null; }
        function activate(w) {}
        function connectMac(mac) {}
        function connectMacAs(mac, user) {}
    }

    Window {
        id: window
        visible: true
        width: 1000
        height: 800
        color: Commons.Color.menu.background

        Item {
            anchors.fill: parent
            MacRow {
                id: row
                width: parent.width
                controller: controller
            }
            DevicePanel {
                id: panel
                anchors.fill: parent
                controller: controller
            }
        }
    }

    function require(condition, message) {
        if (!condition) { console.error("FAIL: " + message); Qt.quit(); throw Error(message); }
    }

    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: {
            if (test.phase === 0) {
                test.require(panel.populated, "panel populated from the controller");
                var drafts = panel.drafts();
                test.require(drafts.length === 2, "two editors, got " + drafts.length);
                test.require(drafts[0].users.length === 2 && drafts[0].users[0].name === "gustavo", "users copied into the editor");
                test.require(drafts[1].protocol === "ssh" && drafts[1].users.length === 0, "defaults for a new device");
                var built = DeviceModel.buildPayload(drafts).errors.length === 0;
                test.require(built, "drafts validate");
                test.phase++;
            } else if (test.phase === 1) {
                test.require(row.macs.length === 2, "row lists both devices");
                test.require(row.implicitHeight > 0, "row has height");
                console.log("PASS: device panel and row load against the real theme");
                Qt.quit();
            }
        }
    }

    QtObject {
        id: deviceBuildHelper
    }
}
