import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "DeviceModel.js" as DeviceModel
import qs.Commons // qmllint disable import
import qs.Commons as Commons // qmllint disable import

// Configuration for every computer device on the network, inside Exposé.
// Exposé holds the keyboard, so this panel is a FocusScope whose text fields
// take focus themselves: Overview.handleKey leaves every key except Escape
// unhandled while the panel is open, so typing reaches the focused field, Tab
// moves along the focus chain, and Escape closes the panel (without saving).
// All file access goes through ./device-config; this file never writes.
FocusScope {
    id: panel

    required property var controller
    property bool populated: false
    property bool saving: false
    property var errors: []
    property string addError: ""
    property string addProtocol: "vnc"
    readonly property color ink: Commons.Color.menu.text
    readonly property var loadedDevices: panel.controller.macResults.devices || []

    // Called by Overview when the panel is shown or fresh data arrives.
    function populate() {
        if (panel.populated || !panel.controller.macLoaded)
            return;
        panel.populated = true;
        devicesModel.clear();
        var list = panel.loadedDevices;
        for (var i = 0; i < list.length; i++)
            devicesModel.append({ devId: String(list[i].id), cfg: list[i].config, live: list[i] });
    }

    function existingIds() {
        var ids = [];
        for (var i = 0; i < devicesModel.count; i++)
            ids.push(devicesModel.get(i).devId);
        return ids;
    }

    function drafts() {
        var out = [];
        for (var i = 0; i < editors.count; i++) {
            var item = editors.itemAt(i);
            if (item)
                out.push(item.collect()); // qmllint disable missing-property
        }
        return out;
    }

    function problemsFor(editorLabel) {
        var prefix = editorLabel + ": ";
        return panel.errors.filter(function (e) { return String(e).indexOf(prefix) === 0; })
            .map(function (e) { return String(e).substring(prefix.length); });
    }

    function save() {
        if (panel.saving)
            return;
        var built = DeviceModel.buildPayload(panel.drafts());
        if (built.errors.length) {
            panel.errors = built.errors;
            return;
        }
        panel.errors = [];
        panel.saving = true;
        saveProc.payload = built.payload;
        saveProc.command = [panel.controller.pluginDir + "/device-config", "save"];
        saveProc.running = true;
    }

    function addManual() {
        var nameText = addName.text.trim();
        var address = addAddress.text.trim();
        var problem = DeviceModel.addressProblem(address);
        if (nameText === "" && address === "")
            problem = "enter a name or an address";
        else if (address === "")
            problem = "an address is required for a device that is not on Tailscale";
        if (problem) {
            panel.addError = problem;
            return;
        }
        var id = DeviceModel.manualId(nameText || address, panel.existingIds());
        var cfg = { id: id, match: "", name: nameText, address: address, protocol: panel.addProtocol,
            port: null, alwaysOn: true, hidden: false, notes: "", users: [] };
        devicesModel.append({ devId: id, cfg: cfg, live: { source: "manual", hostName: "" } });
        addName.text = "";
        addAddress.text = "";
        panel.addError = "";
        addForm.expanded = false;
        Qt.callLater(function () { flick.contentY = Math.max(0, flick.contentHeight - flick.height); });
    }

    function isInside(item, ancestor) {
        while (item) {
            if (item === ancestor)
                return true;
            item = item.parent;
        }
        return false;
    }

    // Keeps the focused field on screen when Tab moves through a long list.
    function reveal(item) {
        if (!item || !flick.contentItem)
            return;
        var p = item.mapToItem(flick.contentItem, 0, 0);
        if (p.y < flick.contentY)
            flick.contentY = Math.max(0, p.y - Style.spacing.md);
        else if (p.y + item.height > flick.contentY + flick.height)
            flick.contentY = p.y + item.height - flick.height + Style.spacing.md;
    }

    Component.onCompleted: {
        panel.populate();
        panel.forceActiveFocus();
    }

    Connections {
        target: panel.controller

        function onMacLoadedChanged() {
            panel.populate();
        }
    }

    Connections {
        target: panel.Window.window

        function onActiveFocusItemChanged() {
            var item = panel.Window.window ? panel.Window.window.activeFocusItem : null;
            if (panel.isInside(item, flick.contentItem))
                panel.reveal(item);
        }
    }

    ListModel {
        id: devicesModel
        dynamicRoles: true
    }

    Process {
        id: saveProc
        property string payload: ""
        stdinEnabled: true
        onStarted: {
            write(payload);
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                panel.saving = false;
                var reply = DeviceModel.parseSaveReply(this.text);
                if (!reply.ok) {
                    panel.errors = reply.errors;
                    return;
                }
                panel.controller.devicesSaved();
            }
        }
    }

    // Swallows clicks so the grid underneath does not react.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.space(820), panel.width - Style.space(48))
        height: panel.height - Style.space(64)
        radius: Style.cornerRadius
        color: Commons.Color.menu.background
        border.width: 1
        border.color: Qt.rgba(panel.ink.r, panel.ink.g, panel.ink.b, 0.25)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.spacing.lg
            spacing: Style.spacing.md

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Devices"
                        textFormat: Text.PlainText
                        color: panel.ink
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.heading
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Computers on your Tailscale network. Saved to ~/.config/omarchy/expose-devices.json. Passwords are never stored: Remmina asks when you connect."
                        textFormat: Text.PlainText
                        color: panel.ink
                        opacity: 0.55
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.Wrap
                    }
                }

                DeviceButton {
                    Layout.alignment: Qt.AlignTop
                    label: "Esc"
                    onActivated: panel.controller.closeDevices()
                }
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: body
                    width: flick.width - Style.spacing.md
                    spacing: Style.spacing.sm

                    Text {
                        Layout.fillWidth: true
                        visible: !panel.populated
                        text: "Looking for devices…"
                        textFormat: Text.PlainText
                        color: panel.ink
                        opacity: 0.6
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.body
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: panel.populated && devicesModel.count === 0
                        text: "No computers found on Tailscale. Add one manually below."
                        textFormat: Text.PlainText
                        color: panel.ink
                        opacity: 0.6
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.body
                        wrapMode: Text.Wrap
                    }

                    Repeater {
                        id: editors
                        model: devicesModel

                        DeviceEditor {
                            id: deviceEditor
                            required property int index
                            Layout.fillWidth: true
                            problems: panel.problemsFor(deviceEditor.label)
                            onRemoveRequested: devicesModel.remove(deviceEditor.index)
                        }
                    }

                    // Add a device that Tailscale does not know about.
                    Rectangle {
                        id: addForm
                        property bool expanded: false
                        Layout.fillWidth: true
                        implicitHeight: addColumn.implicitHeight + Style.spacing.md * 2
                        radius: Style.cornerRadius
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(panel.ink.r, panel.ink.g, panel.ink.b, 0.18)

                        ColumnLayout {
                            id: addColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Style.spacing.md
                            spacing: Style.spacing.sm

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Style.space(28)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (addForm.expanded ? "▾  " : "▸  ") + "Add device manually"
                                    textFormat: Text.PlainText
                                    color: panel.ink
                                    font.family: Style.font.menuFamily
                                    font.pixelSize: Style.font.body
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: addForm.expanded = !addForm.expanded
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: addForm.expanded
                                spacing: Style.spacing.sm

                                DeviceField {
                                    id: addName
                                    Layout.fillWidth: true
                                    label: "Display name"
                                    placeholder: "Office PC"
                                    maximumLength: 64
                                }

                                DeviceField {
                                    id: addAddress
                                    Layout.fillWidth: true
                                    label: "Address"
                                    placeholder: "IP address or host name"
                                    maximumLength: 253
                                    onCommitted: panel.addError = ""
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.spacing.sm

                                    Text {
                                        text: "Protocol"
                                        textFormat: Text.PlainText
                                        color: panel.ink
                                        opacity: 0.6
                                        font.family: Style.font.menuFamily
                                        font.pixelSize: Style.font.caption
                                    }

                                    Repeater {
                                        model: DeviceModel.PROTOCOLS

                                        DeviceButton {
                                            required property string modelData
                                            label: DeviceModel.protocolLabel(modelData)
                                            active: panel.addProtocol === modelData
                                            primary: active
                                            onActivated: panel.addProtocol = modelData
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    DeviceButton {
                                        label: "Add"
                                        primary: true
                                        onActivated: panel.addManual()
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: panel.addError !== ""
                                    text: panel.addError
                                    textFormat: Text.PlainText
                                    color: "#F87171"
                                    font.family: Style.font.menuFamily
                                    font.pixelSize: Style.font.caption
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: panel.errors.length > 0
                text: "Not saved:\n" + panel.errors.join("\n")
                textFormat: Text.PlainText
                color: "#F87171"
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                maximumLineCount: 8
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacing.sm

                Text {
                    Layout.fillWidth: true
                    text: "Tab moves between fields, Enter confirms, Esc closes without saving."
                    textFormat: Text.PlainText
                    color: panel.ink
                    opacity: 0.45
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                }

                DeviceButton {
                    label: "Cancel"
                    onActivated: panel.controller.closeDevices()
                }

                DeviceButton {
                    label: panel.saving ? "Saving…" : "Save"
                    primary: true
                    onActivated: panel.save()
                }
            }
        }
    }
}
