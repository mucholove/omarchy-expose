import QtQuick
import qs.Commons // qmllint disable import
import qs.Commons as Commons // qmllint disable import

// Label, hint and a toggle: the same look as the sidebar's SwitchRow.
Rectangle {
    id: switchRow

    property string label
    property string hint
    property bool checked
    signal toggled()

    implicitHeight: labelColumn.implicitHeight + Style.spacing.md * 2
    height: implicitHeight
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
            visible: switchRow.hint !== ""
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
