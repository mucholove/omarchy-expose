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
    readonly property var rows: AgentModel.sessionRows(sidebar.controller.agentResults, sidebar.controller.nowMs)

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
        model: sidebar.rows
        boundsBehavior: Flickable.StopAtBounds

        header: Text {
            width: list.width
            height: Style.space(30)
            text: sidebar.rows.length ? "Claude Code" : "No Claude Code sessions"
            textFormat: Text.PlainText
            color: Commons.Color.menu.text
            opacity: 0.7
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            leftPadding: Style.spacing.sm
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
            readonly property string branch: session && session.branch ? "  ⎇ " + session.branch : ""
            readonly property string folder: session
                ? AgentModel.folderName(session.cwd, sidebar.controller.homeDirectory) : ""
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
                            text: row.session ? row.session.name : ""
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
                            text: row.stateText
                            textFormat: Text.PlainText
                            color: row.phase === "working" ? Commons.Color.accent : Commons.Color.menu.text
                            opacity: row.phase === "working" ? 1 : 0.75
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.folder + row.branch
                            textFormat: Text.PlainText
                            color: Commons.Color.menu.text
                            opacity: 0.62
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideMiddle
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
}
