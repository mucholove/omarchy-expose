import QtQuick
import QtTest
import "../DeviceModel.js" as DeviceModel

// Validation and editing rules of the devices panel, plus a keyboard harness
// that mirrors how Overview forwards keys: an ancestor with Keys.priority
// BeforeItem (Overview's keyCatcher) that sends printable keys to the search
// unless the panel is open, around plain TextInputs. What this cannot prove
// (the layer-shell window, the real Exposé key catcher, Remmina) needs the
// running shell; see README.
TestCase {
    id: test
    name: "DeviceModel"
    when: windowShown
    visible: true
    width: 400
    height: 300

    property string search: ""
    property int closeRequests: 0
    property bool panelOpen: true

    function draft(over) {
        var base = { id: "mac-mini", match: "mini", name: "Mac mini", address: "", protocol: "vnc", port: "",
            alwaysOn: true, hidden: false, notes: "", users: [{ name: "gustavo", label: "Gustavo" }] };
        for (var key in over)
            base[key] = over[key];
        return base;
    }

    function test_validEntry() {
        var built = DeviceModel.buildEntry(draft({}));
        compare(built.errors.length, 0);
        compare(built.entry.port, null);
        compare(built.entry.users.length, 1);
        compare(DeviceModel.buildEntry(draft({ port: " 3390 " })).entry.port, 3390);
    }

    function test_addresses() {
        compare(DeviceModel.addressProblem(""), "");
        compare(DeviceModel.addressProblem("100.87.204.116"), "");
        compare(DeviceModel.addressProblem("fd7a:115c:a1e0::3501:cc8d"), "");
        compare(DeviceModel.addressProblem("nas.example.com"), "");
        verify(DeviceModel.addressProblem("a b") !== "");
        verify(DeviceModel.addressProblem("host;rm -rf /") !== "");
        verify(DeviceModel.addressProblem("user:pw@host") !== "");
        verify(DeviceModel.addressProblem("-oProxyCommand=x") !== "");
        verify(DeviceModel.addressProblem("fe80::1%eth0") !== "");
        verify(DeviceModel.addressProblem("$(id)") !== "");
        compare(DeviceModel.safeAddress("good.host"), "good.host");
        compare(DeviceModel.safeAddress("bad host"), "");
    }

    function test_portsAndUsers() {
        compare(DeviceModel.parsePort("").value, null);
        compare(DeviceModel.parsePort("22").value, 22);
        verify(DeviceModel.parsePort("0").error !== "");
        verify(DeviceModel.parsePort("65536").error !== "");
        verify(DeviceModel.parsePort("22a").error !== "");
        compare(DeviceModel.userProblem("gustavo.b-1_"), "");
        verify(DeviceModel.userProblem("-oProxy") !== "");
        verify(DeviceModel.userProblem("a b") !== "");
        verify(DeviceModel.userProblem("a/b") !== "");
        verify(DeviceModel.userProblem("a\nb") !== "");
        verify(DeviceModel.userProblem(new Array(66).join("x")) !== "");
    }

    function test_buildEntryNeverDropsInput() {
        var built = DeviceModel.buildEntry(draft({ name: "x\ny", address: "a b", port: "99999", protocol: "telnet",
            users: [{ name: "bad name", label: "" }, { name: "dup", label: "" }, { name: "dup", label: "" }] }));
        verify(built.errors.length >= 6, built.errors.join(" | "));
        // blank user rows are the only thing ignored
        var blank = DeviceModel.buildEntry(draft({ users: [{ name: "", label: "" }, { name: "ok", label: "" }] }));
        compare(blank.errors.length, 0);
        compare(blank.entry.users.length, 1);
    }

    function test_payloadAndIds() {
        var two = DeviceModel.buildPayload([draft({}), draft({})]);
        verify(two.errors.join(" ").indexOf("used twice") >= 0);
        var ok = DeviceModel.buildPayload([draft({})]);
        compare(ok.errors.length, 0);
        compare(JSON.parse(ok.payload).devices[0].id, "mac-mini");
        compare(DeviceModel.manualId("Office PC!", []), "office-pc");
        compare(DeviceModel.manualId("Office PC", ["office-pc"]), "office-pc-2");
        compare(DeviceModel.manualId("", []), "device");
        compare(DeviceModel.manualId("../../etc", []), "etc");
    }

    function test_saveReply() {
        verify(DeviceModel.parseSaveReply("{\"ok\":true,\"errors\":[]}").ok);
        var bad = DeviceModel.parseSaveReply("{\"ok\":false,\"errors\":[\"a: b\"]}");
        verify(!bad.ok);
        compare(bad.errors[0], "a: b");
        verify(!DeviceModel.parseSaveReply("garbage").ok);
        verify(!DeviceModel.parseSaveReply("").ok);
    }

    function test_keyAction() {
        compare(DeviceModel.keyAction(Qt.Key_Escape, Qt.Key_Escape), "close");
        compare(DeviceModel.keyAction(Qt.Key_A, Qt.Key_Escape), "pass");
        compare(DeviceModel.keyAction(Qt.Key_Tab, Qt.Key_Escape), "pass");
    }

    // ---- keyboard harness -------------------------------------------------

    Item {
        id: catcher
        parent: test
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function (event) {
            if (test.panelOpen) {
                if (DeviceModel.keyAction(event.key, Qt.Key_Escape) === "close") {
                    test.closeRequests++;
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
                return;
            }
            if (event.text !== "") {
                test.search += event.text;
                event.accepted = true;
            }
        }

        FocusScope {
            id: scope
            anchors.fill: parent

            Column {
                TextInput {
                    id: first
                    width: 200; height: 30
                    activeFocusOnTab: true
                    property int accepts: 0
                    onAccepted: { accepts++; nextItemInFocusChain(true).forceActiveFocus(); }
                }
                TextInput {
                    id: second
                    width: 200; height: 30
                    activeFocusOnTab: true
                }
            }
        }
    }

    function init() {
        test.search = "";
        test.closeRequests = 0;
        test.panelOpen = true;
        first.text = "";
        second.text = "";
        first.forceActiveFocus();
    }

    function test_typingReachesFieldNotSearch() {
        keyClick(Qt.Key_G);
        keyClick(Qt.Key_U);
        keyClick(Qt.Key_S);
        compare(first.text, "gus");
        compare(test.search, "");
        keyClick(Qt.Key_Backspace);
        compare(first.text, "gu");
        keyClick(Qt.Key_Left);
        keyClick(Qt.Key_X);
        compare(first.text, "gxu");
        keyClick(Qt.Key_Home);
        keyClick(Qt.Key_Y);
        compare(first.text, "ygxu");
        verify(first.activeFocus);
        compare(test.closeRequests, 0);
    }

    function test_enterCommitsAndAdvances() {
        keyClick(Qt.Key_A);
        keyClick(Qt.Key_Return);
        compare(first.accepts, 1);
        verify(second.activeFocus);
        keyClick(Qt.Key_B);
        compare(second.text, "b");
        compare(first.text, "a");
    }

    function test_tabMovesBetweenFields() {
        keyClick(Qt.Key_A);
        keyClick(Qt.Key_Tab);
        verify(second.activeFocus, "Tab should focus the next field");
        keyClick(Qt.Key_B);
        compare(second.text, "b");
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(first.activeFocus, "Shift+Tab should go back");
        compare(test.search, "");
    }

    function test_escapeClosesWithoutTyping() {
        keyClick(Qt.Key_A);
        keyClick(Qt.Key_Escape);
        compare(test.closeRequests, 1);
        compare(first.text, "a");
        compare(test.search, "");
    }

    function test_withoutPanelTypingGoesToSearch() {
        test.panelOpen = false;
        catcher.forceActiveFocus();
        keyClick(Qt.Key_Q);
        compare(test.search, "q");
        compare(first.text, "");
    }
}
