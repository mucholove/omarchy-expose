import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import "MacModel.js" as MacModel
import "WindowModel.js" as WindowModel
import qs.Commons
import qs.Commons as Commons

// One card per device along the top of the card space, under a "Devices"
// header with a gear that opens the configuration panel. A remote-desktop
// window for the device replaces the glyph with its live preview.
Item {
    id: row

    required property var controller
    readonly property var macs: MacModel.sortDevices(
        row.controller.macList.filter(function (d) { return d.hidden !== true; }), row.controller.deviceSort)

    implicitHeight: Style.space(34) + (row.macs.length > 0 ? Style.space(184) : 0)

    Item {
        id: headerBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Style.space(34)

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            text: "Devices"
            textFormat: Text.PlainText
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.55)
            color: Commons.Color.menu.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
            font.bold: true
        }

        SortToggle {
            anchors.right: gear.left
            anchors.rightMargin: Style.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            value: row.controller.deviceSort
            outlined: true
            onPicked: function (key) { row.controller.setDeviceSort(key); }
        }

        Rectangle {
            id: gear
            width: Style.space(28)
            height: width
            radius: Style.cornerRadius
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: row.controller.devicesOpen || gearMouse.containsMouse
                ? Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g, Commons.Color.menu.text.b, 0.16)
                : Qt.rgba(Commons.Color.menu.background.r, Commons.Color.menu.background.g, Commons.Color.menu.background.b, 0.5)

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
                onClicked: row.controller.devicesOpen ? row.controller.closeDevices() : row.controller.openDevices()
            }
        }
    }

    ListView {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerBar.bottom
        anchors.bottom: parent.bottom
        orientation: ListView.Horizontal
        spacing: Style.spacing.sm
        clip: true
        model: row.macs
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        // Two-finger horizontal swipe (or a mouse wheel) scrolls the row sideways.
        WheelHandler {
            acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse
            onWheel: function (event) {
                var dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x
                    : (event.angleDelta.x !== 0 ? event.angleDelta.x / 2 : 0);
                var dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y
                    : (event.angleDelta.y !== 0 ? event.angleDelta.y / 2 : 0);
                var move = Math.abs(dx) >= Math.abs(dy) ? dx : dy;
                var max = Math.max(0, list.contentWidth - list.width);
                list.contentX = Math.max(0, Math.min(max, list.contentX - move));
            }
        }

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
            readonly property var address: MacModel.addressInfo(card.mac)
            readonly property var plan: MacModel.connectPlan(card.mac)
            property bool choosing: false
            readonly property color ink: Commons.Color.menu.text

            // Share the row when there are only a few devices; keep a floor and scroll beyond it.
            width: Math.max(Style.space(230), Math.min(Style.space(340),
                (list.width - Style.spacing.sm * (list.count - 1)) / Math.max(1, list.count)))
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
                    Layout.preferredWidth: Style.space(96)
                    Layout.fillHeight: true
                    radius: Math.max(0, Style.cornerRadius - Style.spacing.sm)
                    color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.08)
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        visible: !card.remoteWindow
                        text: MacModel.osGlyph(card.mac)
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

                    ColumnLayout {
                    id: info
                    Layout.fillWidth: true
                    visible: !card.choosing
                    spacing: 2

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
                        id: dnsText
                        Layout.fillWidth: true
                        visible: card.address.dns !== ""
                        text: card.address.dns
                        textFormat: Text.PlainText
                        color: card.ink
                        opacity: dnsMouse.containsMouse ? 1 : 0.6
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideMiddle

                        MouseArea {
                            id: dnsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: row.controller.copyAddress(card.address.dns)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: card.address.ip !== "" || card.address.connection !== ""
                        spacing: Style.spacing.sm

                        Text {
                            id: ipText
                            visible: card.address.ip !== ""
                            text: card.address.ip
                            textFormat: Text.PlainText
                            color: card.ink
                            opacity: ipMouse.containsMouse ? 1 : 0.6
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.font.caption

                            MouseArea {
                                id: ipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: row.controller.copyAddress(card.address.ip)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.address.connection + (card.address.lan !== "" ? "  ·  LAN " + card.address.lan : "")
                            textFormat: Text.PlainText
                            color: card.ink
                            opacity: 0.45
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }
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
                    }

                    ListView {
                        id: chooser
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: card.choosing
                        clip: true
                        spacing: 3
                        model: card.plan.users
                        boundsBehavior: Flickable.StopAtBounds
                        header: Text {
                            width: chooser.width
                            height: implicitHeight + 3
                            text: "Connect as"
                            textFormat: Text.PlainText
                            color: card.ink
                            opacity: 0.6
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.font.caption
                        }

                        delegate: Rectangle {
                            id: userButton
                            required property var modelData
                            width: chooser.width
                            height: Style.space(26)
                            radius: Math.max(0, Style.cornerRadius - Style.spacing.sm)
                            color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, userMouse.containsMouse ? 0.22 : 0.1)

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: Style.spacing.sm
                                anchors.rightMargin: Style.spacing.sm
                                verticalAlignment: Text.AlignVCenter
                                text: MacModel.userText(userButton.modelData)
                                textFormat: Text.PlainText
                                color: card.ink
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.font.bodySmall
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: userMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    card.choosing = false;
                                    row.controller.connectMacAs(card.mac, userButton.modelData.name);
                                }
                            }
                        }
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
                            text: card.remoteWindow ? "Show" : (card.choosing ? "Cancel" : "Connect")
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
                            onClicked: {
                                if (card.remoteWindow)
                                    row.controller.activate(card.remoteWindow);
                                else if (card.plan.kind === "choose")
                                    card.choosing = !card.choosing;
                                else
                                    row.controller.connectMac(card.mac);
                            }
                        }
                    }
                }
            }
        }
    }
}
