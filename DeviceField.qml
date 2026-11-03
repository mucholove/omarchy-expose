import QtQuick
import qs.Commons // qmllint disable import
import qs.Commons as Commons // qmllint disable import

// Labeled single-line text field. Typing, Backspace and the arrow keys go to
// the TextInput. Escape is left unhandled so it reaches Exposé's key handler
// (which closes the panel); Tab moves to the next field through the window's
// focus chain; Enter commits and advances to the next field.
Item {
    id: field

    property string label
    property string placeholder
    property string error
    property bool readOnly: false
    property alias text: input.text
    property alias inputItem: input
    property alias maximumLength: input.maximumLength
    signal committed()
    signal edited()

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 2

        Text {
            visible: field.label !== ""
            text: field.label
            textFormat: Text.PlainText
            color: Commons.Color.menu.text
            opacity: 0.6
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
        }

        Rectangle {
            width: parent.width
            height: Style.space(30)
            radius: Math.max(0, Style.cornerRadius - Style.spacing.sm)
            color: Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g, Commons.Color.menu.text.b, field.readOnly ? 0.04 : 0.1)
            border.width: 1
            border.color: field.error !== "" ? "#F87171"
                : (input.activeFocus ? Commons.Color.accent
                    : Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g, Commons.Color.menu.text.b, 0.2))

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: Style.spacing.sm
                anchors.rightMargin: Style.spacing.sm
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                readOnly: field.readOnly
                selectByMouse: true
                activeFocusOnTab: !field.readOnly
                color: Commons.Color.menu.text
                selectionColor: Commons.Color.accent
                selectedTextColor: Commons.Color.menu.background
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
                maximumLength: 600
                onTextEdited: field.edited()
                onAccepted: {
                    field.committed();
                    var next = input.nextItemInFocusChain(true);
                    if (next && next !== input)
                        next.forceActiveFocus();
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text === "" && !input.preeditText
                    text: field.placeholder
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Commons.Color.menu.text
                    opacity: 0.4
                    font: input.font
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: field.readOnly
                cursorShape: Qt.ArrowCursor
            }
        }

        Text {
            width: parent.width
            visible: field.error !== ""
            text: field.error
            textFormat: Text.PlainText
            color: "#F87171"
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
        }
    }
}
