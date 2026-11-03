import QtQuick
import qs.Commons // qmllint disable import
import qs.Commons as Commons // qmllint disable import

// "recent · A–Z": two small text options, the current one underlined.
Row {
    id: toggle

    property string value: "recent"
    property bool outlined: false
    signal picked(string value)
    spacing: Style.spacing.sm

    Repeater {
        model: [{ key: "recent", label: "recent" }, { key: "az", label: "A–Z" }]

        Text {
            id: option
            required property var modelData
            readonly property bool active: toggle.value === modelData.key
            text: modelData.label
            textFormat: Text.PlainText
            style: toggle.outlined ? Text.Outline : Text.Normal
            styleColor: Qt.rgba(0, 0, 0, 0.55)
            color: active ? Commons.Color.accent : Commons.Color.menu.text
            opacity: active ? 1 : (optionMouse.containsMouse ? 0.9 : 0.5)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            font.underline: active

            MouseArea {
                id: optionMouse
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: toggle.picked(option.modelData.key)
            }
        }
    }
}
