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
    property string confirmId: ""
    property string menuId: ""
    readonly property var rows: AgentModel.sessionRows(sidebar.controller.agentResults, sidebar.controller.nowMs, {
        showOlder: sidebar.controller.showOlderSessions,
        showEnded: sidebar.controller.showEndedSessions,
        showArchived: sidebar.controller.showArchivedSessions
    })

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
                text: sidebar.rows.length ? "AI sessions" : "No AI sessions"
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
                : (phase === "shell" ? "running a command " + age
                : (phase === "ended" ? "last active " + age + " ago" : "waits for you " + age))
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
                else if (AgentModel.tokensText(session.tokens))
                    parts.push(AgentModel.tokensText(session.tokens) + " tokens used");
                var model = AgentModel.modelLabel(session.model);
                if (model)
                    parts.push(model);
                if (session.kind === "bg")
                    parts.push("background");
                return parts.join("  ·  ");
            }
            readonly property var chips: AgentModel.sessionChips(session)
            readonly property bool menuShown: session !== null && sidebar.menuId === session.id
            readonly property bool confirming: session !== null && sidebar.confirmId === session.id
            readonly property bool canFree: AgentModel.canFreeWorktree(session)
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
                        source: Qt.resolvedUrl("assets/agents/" + (row.session && row.session.agent === "codex" ? "codex" : "claude") + ".svg")
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
                                        : (modelData.kind === "unmerged" ? "#60A5FA"
                                        : (modelData.kind === "size" ? "#A8A29E"
                                        : (modelData.kind === "usage" ? "#2DD4BF"
                                        : (modelData.kind === "hot" ? "#F87171" : "#4ADE80"))))
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

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: row.menuShown
                            spacing: 2

                            MenuItem {
                                visible: row.windowTop !== null
                                label: "Jump to window"
                                onActivated: { sidebar.menuId = ""; sidebar.controller.activate(row.windowTop); }
                            }
                            MenuItem {
                                visible: row.session && !row.session.live && row.session.cwdExists === true
                                label: "Resume here"
                                onActivated: { sidebar.menuId = ""; sidebar.controller.resumeSession(row.session); }
                            }
                            MenuItem {
                                visible: row.session && row.session.kind === "bg" && row.session.live === true
                                label: "Attach in a terminal"
                                onActivated: { sidebar.menuId = ""; sidebar.controller.resumeSession(row.session); }
                            }
                            MenuItem {
                                label: "Copy session id"
                                onActivated: { sidebar.menuId = ""; sidebar.controller.copyText(row.session.id); }
                            }
                            MenuItem {
                                visible: row.session && row.session.cwdExists === true
                                label: "Open folder in Files"
                                onActivated: { sidebar.menuId = ""; sidebar.controller.openFolder(row.session.cwd); }
                            }
                            MenuItem {
                                visible: row.session && row.session.archived !== true
                                label: row.canFree ? "Archive or free worktree…" : "Archive…"
                                onActivated: { sidebar.menuId = ""; sidebar.confirmId = row.session.id; }
                            }
                            MenuItem {
                                visible: row.session && row.session.archived === true
                                label: "Restore"
                                onActivated: { sidebar.menuId = ""; sidebar.controller.restoreSession(row.session); }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            visible: !row.confirming && (cardHover.hovered || row.session.archived === true)
                            spacing: Style.spacing.sm

                            ActionButton {
                                visible: row.session && !row.session.live && row.session.cwdExists === true
                                label: "Resume here"
                                onActivated: sidebar.controller.resumeSession(row.session)
                            }

                            ActionButton {
                                visible: row.session && row.session.kind === "bg" && row.session.live === true
                                label: "Attach"
                                onActivated: sidebar.controller.resumeSession(row.session)
                            }

                            ActionButton {
                                visible: row.session && row.session.archived !== true
                                label: "Archive…"
                                onActivated: sidebar.confirmId = row.session.id
                            }

                            ActionButton {
                                visible: row.session && row.session.archived === true
                                label: "Restore"
                                onActivated: sidebar.controller.restoreSession(row.session)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: row.confirming
                            spacing: Style.spacing.sm

                            Text {
                                Layout.fillWidth: true
                                text: row.canFree ? AgentModel.freeSummary(row.session)
                                    : "Hides it from this list. Nothing is deleted."
                                textFormat: Text.PlainText
                                color: Commons.Color.menu.text
                                opacity: 0.85
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.font.caption
                                wrapMode: Text.Wrap
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: Style.spacing.sm

                                ActionButton {
                                    label: "Archive"
                                    onActivated: {
                                        sidebar.confirmId = "";
                                        sidebar.controller.archiveSession(row.session, false);
                                    }
                                }

                                ActionButton {
                                    visible: row.canFree
                                    label: "Archive & free worktree"
                                    danger: true
                                    onActivated: {
                                        sidebar.confirmId = "";
                                        sidebar.controller.archiveSession(row.session, true);
                                    }
                                }

                                ActionButton {
                                    label: "Cancel"
                                    onActivated: sidebar.confirmId = ""
                                }
                            }
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

                HoverHandler {
                    id: cardHover
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    z: -1
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: row.windowTop ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: function (mouse) {
                        if (mouse.button === Qt.RightButton) {
                            sidebar.confirmId = "";
                            sidebar.menuId = row.menuShown ? "" : row.session.id;
                        } else if (row.windowTop) {
                            sidebar.controller.activate(row.windowTop);
                        }
                    }
                }
            }
        }
    }

    component MenuItem: Rectangle {
        id: item
        property string label
        signal activated()
        Layout.fillWidth: true
        implicitHeight: itemText.implicitHeight + Style.spacing.md
        radius: Style.cornerRadius
        color: itemMouse.containsMouse
            ? Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g, Commons.Color.menu.text.b, 0.16)
            : Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g, Commons.Color.menu.text.b, 0.06)

        Text {
            id: itemText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.md
            text: item.label
            textFormat: Text.PlainText
            color: Commons.Color.menu.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
        }

        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: item.activated()
        }
    }

    component ActionButton: Rectangle {
        id: button
        property string label
        property bool danger: false
        signal activated()
        width: buttonText.implicitWidth + Style.spacing.md * 2
        height: buttonText.implicitHeight + Style.spacing.sm
        radius: Style.cornerRadius
        readonly property color tone: danger ? "#F87171" : Commons.Color.menu.text
        color: Qt.rgba(tone.r, tone.g, tone.b, buttonMouse.containsMouse ? 0.26 : 0.12)
        border.width: 1
        border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.4)

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button.label
            textFormat: Text.PlainText
            color: button.tone
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    Rectangle {
        visible: sidebar.controller.sessionActionMessage !== ""
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Style.spacing.md
        height: messageText.implicitHeight + Style.spacing.md * 2
        radius: Style.cornerRadius
        color: Commons.Color.menu.background
        border.width: 1
        border.color: Commons.Color.accent
        z: 30

        Text {
            id: messageText
            anchors.fill: parent
            anchors.margins: Style.spacing.md
            text: sidebar.controller.sessionActionMessage
            textFormat: Text.PlainText
            color: Commons.Color.menu.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
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
            label: "Hide AI session windows"
            hint: "Keep Claude Code and Codex windows out of the grid. Click a session here to jump to its window."
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
            label: "Show activity monitor"
            hint: "CPU, GPU and memory, and what AI sessions use."
            checked: sidebar.controller.showActivity
            onToggled: sidebar.controller.setShowActivity(!sidebar.controller.showActivity)
        }

        SwitchRow {
            label: "Show Macs"
            hint: "Your Macs on Tailscale, with Connect and an always-on warning."
            checked: sidebar.controller.showMacs
            onToggled: sidebar.controller.setShowMacs(!sidebar.controller.showMacs)
        }

        SwitchRow {
            label: "Show sessions that ended"
            hint: "Recent sessions with no running Claude Code, to resume."
            checked: sidebar.controller.showEndedSessions
            onToggled: sidebar.controller.setShowEndedSessions(!sidebar.controller.showEndedSessions)
        }

        SwitchRow {
            label: "Show archived"
            hint: "Archived sessions, with a Restore button."
            checked: sidebar.controller.showArchivedSessions
            onToggled: sidebar.controller.setShowArchivedSessions(!sidebar.controller.showArchivedSessions)
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
