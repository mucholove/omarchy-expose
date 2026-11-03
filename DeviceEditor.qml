import QtQuick
import QtQuick.Layouts
import "DeviceModel.js" as DeviceModel
import "MacModel.js" as MacModel
import qs.Commons // qmllint disable import
import qs.Commons as Commons // qmllint disable import

// Collapsible editor for one device. It copies `cfg` once on creation and keeps
// the edits in its own fields; collect() hands them back as a draft. Nothing
// here is bound back to the model, so typing never rebuilds anything.
Rectangle {
    id: editor

    required property var cfg
    required property var live
    property bool expanded: false
    // Validation errors that name this device, from the panel.
    property var problems: []
    readonly property string label: nameField.text.trim() !== "" ? nameField.text.trim() : String(cfg.id)
    readonly property bool removable: Boolean(live) && live.source !== "tailscale"
    property string protocol: String(cfg.protocol || "vnc")
    property bool alwaysOn: cfg.alwaysOn !== false
    property bool hidden: cfg.hidden === true
    readonly property var info: MacModel.addressInfo(live)
    readonly property color ink: Commons.Color.menu.text

    signal removeRequested()

    implicitHeight: content.implicitHeight + Style.spacing.md * 2
    radius: Style.cornerRadius
    color: Qt.rgba(Commons.Color.menu.background.r, Commons.Color.menu.background.g, Commons.Color.menu.background.b, 0.6)
    border.width: 1
    border.color: editor.problems.length ? "#F87171" : Qt.rgba(ink.r, ink.g, ink.b, 0.18)

    function collect() {
        var users = [];
        for (var i = 0; i < usersModel.count; i++)
            users.push({ name: usersModel.get(i).userName, label: usersModel.get(i).userLabel });
        return {
            id: String(cfg.id),
            match: String(cfg.match || ""),
            name: nameField.text,
            address: addressField.text,
            protocol: editor.protocol,
            port: portField.text,
            alwaysOn: editor.alwaysOn,
            hidden: editor.hidden,
            notes: notesField.text,
            users: users
        };
    }

    function addUser(name, label) {
        usersModel.append({ userName: name, userLabel: label });
    }

    ListModel { id: usersModel }

    Component.onCompleted: {
        nameField.text = String(cfg.name || "");
        addressField.text = String(cfg.address || "");
        portField.text = cfg.port ? String(cfg.port) : "";
        notesField.text = String(cfg.notes || "");
        var users = cfg.users || [];
        for (var i = 0; i < users.length; i++)
            editor.addUser(String(users[i].name), String(users[i].label || ""));
        if (editor.problems.length)
            editor.expanded = true;
    }

    onProblemsChanged: if (problems.length) expanded = true

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.spacing.md
        spacing: Style.spacing.sm

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(28)

            Text {
                id: arrow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: editor.expanded ? "▾" : "▸"
                textFormat: Text.PlainText
                color: editor.ink
                font.pixelSize: Style.font.body
            }

            Text {
                anchors.left: arrow.right
                anchors.leftMargin: Style.spacing.sm
                anchors.right: summary.left
                anchors.rightMargin: Style.spacing.sm
                anchors.verticalCenter: parent.verticalCenter
                text: editor.label + (editor.hidden ? "  (hidden)" : "")
                textFormat: Text.PlainText
                color: editor.ink
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                id: summary
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: DeviceModel.protocolLabel(editor.protocol) + (usersModel.count ? "  ·  " + usersModel.count + (usersModel.count === 1 ? " user" : " users") : "  ·  no users")
                textFormat: Text.PlainText
                color: editor.ink
                opacity: 0.55
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: editor.expanded = !editor.expanded
            }
        }

        Text {
            Layout.fillWidth: true
            visible: editor.problems.length > 0 && !editor.expanded
            text: editor.problems.join("\n")
            textFormat: Text.PlainText
            color: "#F87171"
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: editor.expanded
            spacing: Style.spacing.sm

            // What Tailscale reports: read-only, selectable.
            RowLayout {
                Layout.fillWidth: true
                visible: editor.info.dns !== "" || editor.info.ip !== ""
                spacing: Style.spacing.sm

                DeviceField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 3
                    Layout.alignment: Qt.AlignTop
                    visible: editor.info.dns !== ""
                    label: "MagicDNS name"
                    readOnly: true
                    text: editor.info.dns
                }

                DeviceField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 2
                    Layout.alignment: Qt.AlignTop
                    visible: editor.info.ip !== ""
                    label: "Tailscale IP"
                    readOnly: true
                    text: editor.info.ip
                }

                DeviceField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 2
                    Layout.alignment: Qt.AlignTop
                    visible: editor.info.connection !== ""
                    label: "Connection"
                    readOnly: true
                    text: editor.info.connection + (editor.info.lan !== "" ? " · " + editor.info.lan : "")
                }
            }

            DeviceField {
                id: nameField
                Layout.fillWidth: true
                label: "Display name"
                placeholder: editor.live && editor.live.hostName ? editor.live.hostName : String(editor.cfg.id)
                maximumLength: 64
            }

            DeviceField {
                id: addressField
                Layout.fillWidth: true
                label: "Address override (leave empty to use Tailscale)"
                placeholder: editor.info.dns !== "" ? editor.info.dns : (editor.info.ip !== "" ? editor.info.ip : "IP address or host name")
                maximumLength: 253
                error: DeviceModel.addressProblem(addressField.text)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacing.sm

                Text {
                    text: "Protocol"
                    textFormat: Text.PlainText
                    color: editor.ink
                    opacity: 0.6
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.caption
                }

                Repeater {
                    model: DeviceModel.PROTOCOLS

                    DeviceButton {
                        required property string modelData
                        label: DeviceModel.protocolLabel(modelData)
                        active: editor.protocol === modelData
                        primary: active
                        onActivated: editor.protocol = modelData
                    }
                }

                Item { Layout.fillWidth: true }

                DeviceField {
                    id: portField
                    Layout.preferredWidth: Style.space(190)
                    Layout.alignment: Qt.AlignTop
                    label: "Port"
                    placeholder: "default " + DeviceModel.defaultPort(editor.protocol)
                    maximumLength: 5
                    error: DeviceModel.parsePort(portField.text).error
                }
            }

            DeviceSwitch {
                Layout.fillWidth: true
                label: "Expected to be always on"
                hint: "Warn when this Mac sleeps. Other systems only show online or offline."
                checked: editor.alwaysOn
                onToggled: editor.alwaysOn = !editor.alwaysOn
            }

            DeviceSwitch {
                Layout.fillWidth: true
                label: "Hide from the row"
                hint: "Keep it here in the gear, off the Devices row."
                checked: editor.hidden
                onToggled: editor.hidden = !editor.hidden
            }

            DeviceField {
                id: notesField
                Layout.fillWidth: true
                label: "Notes"
                placeholder: "Anything worth remembering"
                maximumLength: 500
            }

            Text {
                text: "Users"
                textFormat: Text.PlainText
                color: editor.ink
                opacity: 0.6
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
            }

            Text {
                Layout.fillWidth: true
                text: "Passwords are never stored here. Remmina asks for one when you connect and can keep it in your keyring."
                textFormat: Text.PlainText
                color: editor.ink
                opacity: 0.45
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
            }

            Repeater {
                model: usersModel

                RowLayout {
                    id: userRow
                    required property int index
                    required property string userName
                    required property string userLabel
                    Layout.fillWidth: true
                    spacing: Style.spacing.sm

                    DeviceField {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 2
                        Layout.alignment: Qt.AlignTop
                        placeholder: "Username"
                        maximumLength: 64
                        error: text !== "" ? DeviceModel.userProblem(text) : ""
                        Component.onCompleted: text = userRow.userName
                        onEdited: usersModel.setProperty(userRow.index, "userName", text)
                    }

                    DeviceField {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 2
                        Layout.alignment: Qt.AlignTop
                        placeholder: "Label (optional)"
                        maximumLength: 64
                        Component.onCompleted: text = userRow.userLabel
                        onEdited: usersModel.setProperty(userRow.index, "userLabel", text)
                    }

                    DeviceButton {
                        Layout.alignment: Qt.AlignTop
                        label: "Remove"
                        danger: true
                        onActivated: usersModel.remove(userRow.index)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacing.sm

                DeviceButton {
                    label: "Add user"
                    onActivated: editor.addUser("", "")
                }

                Item { Layout.fillWidth: true }

                DeviceButton {
                    visible: editor.removable
                    label: "Remove device"
                    danger: true
                    onActivated: editor.removeRequested()
                }
            }

            Text {
                Layout.fillWidth: true
                visible: editor.problems.length > 0
                text: editor.problems.join("\n")
                textFormat: Text.PlainText
                color: "#F87171"
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
            }
        }
    }
}
