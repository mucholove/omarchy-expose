import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import "MacModel.js" as MacModel
import "WindowModel.js" as WindowModel
import qs.Commons
import qs.Commons as Commons

// One card per Mac along the top of the card space. A remote-desktop window for
// the Mac replaces the glyph with its live preview.
Item {
    id: row

    required property var controller
    readonly property var macs: row.controller.macList

    implicitHeight: Style.space(132)

    ListView {
        id: list
        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: Style.spacing.sm
        clip: true
        model: row.macs
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: card
            required property var modelData
            readonly property var mac: modelData
            readonly property var remoteWindow: {
                var revision = row.controller.modelRevision;
                return row.controller.macWindowFor(card.mac);
            }
            readonly property var badge: MacModel.badge(card.mac)
            readonly property string notice: MacModel.screenSharingNotice(card.mac)
            readonly property bool connectable: MacModel.canConnect(card.mac)
            readonly property color ink: Commons.Color.menu.text

            width: Style.space(330)
            height: list.height
            radius: Style.cornerRadius
            color: Qt.rgba(Commons.Color.menu.background.r, Commons.Color.menu.background.g, Commons.Color.menu.background.b, 0.72)
            border.width: 1
            border.color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.18)

            RowLayout {
                anchors.fill: parent
                anchors.margins: Style.spacing.md
                spacing: Style.spacing.md

                Rectangle {
                    Layout.preferredWidth: Style.space(112)
                    Layout.fillHeight: true
                    radius: Math.max(0, Style.cornerRadius - Style.spacing.sm)
                    color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.08)
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        visible: !card.remoteWindow
                        text: "🖥"
                        textFormat: Text.PlainText
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.55)
                        color: card.ink
                        opacity: card.mac.online ? 0.9 : 0.4
                        font.pixelSize: Style.space(44)
                    }

                    ScreencopyView {
                        anchors.fill: parent
                        visible: card.remoteWindow !== null
                        captureSource: card.remoteWindow ? WindowModel.waylandFor(card.remoteWindow) : null
                        live: row.controller.opened && card.remoteWindow !== null
                        paintCursor: false
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: card.remoteWindow !== null
                        cursorShape: Qt.PointingHandCursor
                        onClicked: row.controller.activate(card.remoteWindow)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.spacing.sm

                        Rectangle {
                            Layout.preferredWidth: Style.space(10)
                            Layout.preferredHeight: Style.space(10)
                            radius: width / 2
                            color: MacModel.stateColor(card.mac.state)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.mac.name
                            textFormat: Text.PlainText
                            color: card.ink
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.font.body
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: MacModel.stateText(card.mac) + "  ·  " + MacModel.lastSeenText(card.mac, row.controller.macNowMs)
                        textFormat: Text.PlainText
                        color: card.ink
                        opacity: 0.6
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: card.badge.kind !== "none"
                        text: card.badge.text
                        textFormat: Text.PlainText
                        color: MacModel.badgeColor(card.badge.kind)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: card.notice !== ""
                        text: card.notice
                        textFormat: Text.PlainText
                        color: "#F59E0B"
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        id: connect
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(28)
                        radius: Math.max(0, Style.cornerRadius - Style.spacing.sm)
                        color: !card.connectable ? Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.08)
                            : (connectMouse.containsMouse ? Style.hoverStateColor(card.ink, Commons.Color.accent) : Commons.Color.accent)

                        Text {
                            anchors.centerIn: parent
                            text: card.remoteWindow ? "Show" : "Connect"
                            textFormat: Text.PlainText
                            color: card.connectable ? Commons.Color.menu.background : card.ink
                            opacity: card.connectable ? 1 : 0.45
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.font.bodySmall
                            font.bold: true
                        }

                        MouseArea {
                            id: connectMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: card.connectable || card.remoteWindow !== null
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.remoteWindow ? row.controller.activate(card.remoteWindow) : row.controller.connectMac(card.mac)
                        }
                    }
                }
            }
        }
    }
}
