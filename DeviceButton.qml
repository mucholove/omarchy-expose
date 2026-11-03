import QtQuick
import qs.Commons // qmllint disable import
import qs.Commons as Commons // qmllint disable import

// Small text button in the same look as the session sidebar's ActionButton.
Rectangle {
    id: button

    property string label
    property bool danger: false
    property bool primary: false
    property bool active: false
    signal activated()

    width: buttonText.implicitWidth + Style.spacing.md * 2
    height: buttonText.implicitHeight + Style.spacing.sm
    radius: Style.cornerRadius
    readonly property color tone: danger ? "#F87171" : (primary ? Commons.Color.accent : Commons.Color.menu.text)
    color: Qt.rgba(tone.r, tone.g, tone.b, buttonMouse.containsMouse || active ? 0.26 : (primary ? 0.18 : 0.12))
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
        font.bold: button.primary
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.activated()
    }
}
