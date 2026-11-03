import QtQuick
import QtQuick.Layouts
import "AgentModel.js" as AgentModel
import qs.Commons
import qs.Commons as Commons

// Claude Code sessions, grouped and sorted: working, waiting for you, older.
// Clicking a session that has a window jumps to it.
Item {
    id: sidebar

    required property var controller
    property bool settingsShown: false
    readonly property var rows: AgentModel.sessionRows(sidebar.controller.agentResults, sidebar.controller.nowMs,
        sidebar.controller.showOlderSessions)

    implicitWidth: Style.space(290)

    Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        color: Qt.rgba(Commons.Color.menu.background.r, Commons.Color.menu.background.g, Commons.Color.menu.background.b, 0.72)
        border.width: 1
        border.color: Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g, Commons.Color.menu.text.b, 0.18)
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: Style.spacing.sm
        clip: true
        spacing: Style.spacing.xs
        model: sidebar.settingsShown ? [] : sidebar.rows
        boundsBehavior: Flickable.StopAtBounds

        header: Item {
            width: list.width
            height: Style.space(34)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.spacing.sm
                anchors.verticalCenter: parent.verticalCenter
                text: sidebar.rows.length ? "Claude Code" : "No Claude Code sessions"
                textFormat: Text.PlainText
                color: Commons.Color.menu.text
                opacity: 0.7
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
                font.bold: true
            }

            Rectangle {
                id: gear
                width: Style.space(28)
                height: width
                radius: Style.cornerRadius
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: sidebar.settingsShown || gearMouse.containsMouse
                    ? Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g, Commons.Color.menu.text.b, 0.16)
                    : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "⚙"
                    textFormat: Text.PlainText
                    color: Commons.Color.menu.text
                    font.pixelSize: Style.font.heading
                }

                MouseArea {
                    id: gearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sidebar.settingsShown = !sidebar.settingsShown
                }
            }
        }

        delegate: Item {
            id: row
            required property var modelData
            readonly property var session: modelData.session
            readonly property bool isHeader: !session
            readonly property string phase: session ? AgentModel.sessionState(session) : ""
            readonly property var windowTop: session ? sidebar.controller.toplevelForPid(session.windowPid) : null
            readonly property string age: session ? AgentModel.ageText(session.statusAt, sidebar.controller.nowMs) : ""
            readonly property string stateText: phase === "working" ? "working " + age
                : (phase === "shell" ? "running a command " + age : "waits for you " + age)
            // "worktree-<folder>" repeats the folder, so only other branch names show.
            readonly property string branch: session && session.branch
                && session.branch !== "worktree-" + AgentModel.folderName(session.cwd, "") ? "  ⎇ " + session.branch : ""
            readonly property string folder: session
                ? AgentModel.projectLabel(session.cwd, session.git, sidebar.controller.homeDirectory) : ""
            readonly property string facts: {
                if (!session)
                    return "";
                var parts = [];
                var tokens = AgentModel.tokensText(session.context);
                if (tokens)
                    parts.push(tokens + " context");
                var model = AgentModel.modelLabel(session.model);
                if (model)
                    parts.push(model);
                if (session.kind === "bg")
                    parts.push("background");
                return parts.join("  ·  ");
            }
            readonly property var chips: session ? AgentModel.gitChips(session.git) : []
            readonly property string snippet: session ? String(session.prompt || session.reply || "") : ""

            width: list.width
            height: isHeader ? Style.space(26) : card.implicitHeight + Style.spacing.md

            Text {
                visible: row.isHeader
                anchors.left: parent.left
                anchors.leftMargin: Style.spacing.sm
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.spacing.xs
                text: row.modelData.header
                textFormat: Text.PlainText
                color: Commons.Color.menu.text
                opacity: 0.5
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
                font.capitalization: Font.AllUppercase
            }

            Rectangle {
                id: card
                visible: !row.isHeader
                anchors.fill: parent
                anchors.bottomMargin: Style.spacing.xs
                implicitHeight: content.implicitHeight + Style.spacing.md * 2
                radius: Style.cornerRadius
                color: mouse.containsMouse
                    ? Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g, Commons.Color.menu.text.b, 0.12)
                    : "transparent"
                border.width: row.windowTop && row.windowTop === sidebar.controller.focusedToplevel ? 1 : 0
                border.color: Commons.Color.accent

                RowLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: Style.spacing.md
                    spacing: Style.spacing.md

                    Image {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: Style.space(22)
                        Layout.preferredHeight: Style.space(22)
                        source: Qt.resolvedUrl("assets/agents/claude.svg")
                        sourceSize.width: Style.space(44)
                        sourceSize.height: Style.space(44)
                        opacity: row.windowTop || row.phase === "working" ? 1 : 0.55

                        Rectangle {
                            visible: row.phase === "waiting" && row.age !== "" && row.session && row.session.kind !== "bg"
                                && sidebar.controller.nowMs - row.session.statusAt < 86400000
                            width: Style.space(9)
                            height: width
                            radius: width / 2
                            color: "#F5C451"
                            anchors.right: parent.right
                            anchors.top: parent.top
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.spacing.xs

                        Text {
                            Layout.fillWidth: true
                            text: AgentModel.sessionTitle(row.session)
                            textFormat: Text.PlainText
                            color: Commons.Color.menu.text
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.font.body
                            font.bold: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: AgentModel.sessionGoal(row.session) !== ""
                            text: "Goal: " + AgentModel.sessionGoal(row.session)
                            font.bold: false
                            textFormat: Text.PlainText
                            color: Commons.Color.menu.text
                            opacity: 0.85
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.font.caption
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.stateText
                            textFormat: Text.PlainText
                            color: row.phase === "working" ? Commons.Color.accent : Commons.Color.menu.text
                            opacity: row.phase === "working" ? 1 : 0.75
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.spacing.sm
                            visible: row.folder !== ""

                            Text {
                                Layout.maximumWidth: parent.width * 0.7
                                text: "▸ " + row.folder
                                textFormat: Text.PlainText
                                color: Commons.Color.accent
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.font.body
                                font.bold: true
                                elide: Text.ElideMiddle
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: row.branch !== ""
                                text: row.branch.trim()
                                textFormat: Text.PlainText
                                color: Commons.Color.menu.text
                                opacity: 0.7
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.font.caption
                                elide: Text.ElideMiddle
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            visible: row.chips.length > 0
                            spacing: Style.spacing.xs

                            Repeater {
                                model: row.chips

                                Rectangle {
                                    id: chip
                                    required property var modelData
                                    readonly property color tone: modelData.kind === "dirty" ? "#F59E0B"
                                        : (modelData.kind === "unmerged" ? "#60A5FA" : "#4ADE80")
                                    width: chipText.implicitWidth + Style.spacing.md
                                    height: chipText.implicitHeight + Style.spacing.xs
                                    radius: height / 2
                                    color: Qt.rgba(tone.r, tone.g, tone.b, 0.16)

                                    Text {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: chip.modelData.text
                                        textFormat: Text.PlainText
                                        color: chip.tone
                                        font.family: Style.font.menuFamily
                                        font.pixelSize: Style.font.caption
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: row.snippet !== ""
                            text: (row.session && row.session.prompt ? "“" : "") + row.snippet + (row.session && row.session.prompt ? "”" : "")
                            textFormat: Text.PlainText
                            color: Commons.Color.menu.text
                            opacity: 0.5
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.font.caption
                            font.italic: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: row.facts !== ""
                            text: row.facts
                            textFormat: Text.PlainText
                            color: Commons.Color.menu.text
                            opacity: 0.42
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: row.windowTop !== null
                    cursorShape: row.windowTop ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: sidebar.controller.activate(row.windowTop)
                }
            }
        }
    }

    // Gear panel: a few switches, and a way into Exposé's own settings.
    Column {
        id: panel
        visible: sidebar.settingsShown
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Style.space(44)
        anchors.margins: Style.spacing.md
        spacing: Style.spacing.sm

        component SwitchRow: Rectangle {
            id: switchRow
            property string label
            property string hint
            property bool checked
            signal toggled()
            width: panel.width
            height: labelColumn.implicitHeight + Style.spacing.md * 2
            radius: Style.cornerRadius
            color: switchMouse.containsMouse
                ? Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g, Commons.Color.menu.text.b, 0.1)
                : "transparent"

            Column {
                id: labelColumn
                anchors.left: parent.left
                anchors.right: toggle.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.spacing.md
                anchors.rightMargin: Style.spacing.md
                spacing: 2

                Text {
                    width: parent.width
                    text: switchRow.label
                    textFormat: Text.PlainText
                    color: Commons.Color.menu.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.body
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    text: switchRow.hint
                    textFormat: Text.PlainText
                    color: Commons.Color.menu.text
                    opacity: 0.55
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.Wrap
                }
            }

            Rectangle {
                id: toggle
                anchors.right: parent.right
                anchors.rightMargin: Style.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(38)
                height: Style.space(20)
                radius: height / 2
                color: switchRow.checked ? Commons.Color.accent
                    : Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g, Commons.Color.menu.text.b, 0.25)

                Rectangle {
                    width: parent.height - 4
                    height: width
                    radius: width / 2
                    y: 2
                    x: switchRow.checked ? parent.width - width - 2 : 2
                    color: "white"
                }
            }

            MouseArea {
                id: switchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: switchRow.toggled()
            }
        }

        SwitchRow {
            label: "Hide Claude Code windows"
            hint: "Keep them out of the grid. The list here still jumps to them."
            checked: sidebar.controller.hideAgentWindows
            onToggled: sidebar.controller.setHideAgentWindows(!sidebar.controller.hideAgentWindows)
        }

        SwitchRow {
            label: "Show older sessions"
            hint: "Sessions idle for more than a day."
            checked: sidebar.controller.showOlderSessions
            onToggled: sidebar.controller.setShowOlderSessions(!sidebar.controller.showOlderSessions)
        }

        SwitchRow {
            label: "Hide this list"
            hint: "Ctrl+B brings it back."
            checked: false
            onToggled: sidebar.controller.setSessionSidebar(false)
        }

        SwitchRow {
            label: "Exposé settings…"
            hint: "Appearance, hot corner, motion."
            checked: false
            onToggled: sidebar.controller.openSettings()
        }
    }
}
