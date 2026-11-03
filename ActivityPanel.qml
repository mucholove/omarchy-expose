import QtQuick
import QtQuick.Layouts
import "AgentModel.js" as AgentModel
import qs.Commons // qmllint disable import
import qs.Commons as Commons // qmllint disable import

// CPU (with every core), GPU and memory, plus what the running AI sessions use.
Item {
    id: panel

    required property var system
    required property var totals
    readonly property var cores: panel.system && panel.system.cores ? panel.system.cores : []
    readonly property var gpu: panel.system && panel.system.gpu ? panel.system.gpu : ({})
    readonly property var temps: panel.system && panel.system.temps ? panel.system.temps : ({})
    readonly property bool hasData: panel.cores.length > 0

    implicitHeight: hasData ? column.implicitHeight : 0
    visible: hasData

    function tone(fraction) {
        return fraction > 0.9 ? "#F87171" : (fraction > 0.7 ? "#F59E0B" : Commons.Color.accent);
    }

    component Meter: RowLayout {
        id: meter
        property string label
        property real value: 0
        property string detail
        Layout.fillWidth: true
        spacing: Style.spacing.sm

        Text {
            Layout.preferredWidth: Style.space(34)
            text: meter.label
            textFormat: Text.PlainText
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.55)
            color: Commons.Color.menu.text
            opacity: 0.85
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(8)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.2)

            Rectangle {
                width: parent.width * Math.max(meter.value, meter.value > 0 ? 0.02 : 0)
                height: parent.height
                radius: height / 2
                color: panel.tone(meter.value)

                Behavior on width { NumberAnimation { duration: 250 } }
            }
        }

        Text {
            Layout.preferredWidth: Style.space(112)
            horizontalAlignment: Text.AlignRight
            text: meter.detail
            textFormat: Text.PlainText
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.55)
            color: Commons.Color.menu.text
            opacity: 0.8
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideLeft
        }
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.spacing.xs

        Meter {
            label: "CPU"
            value: panel.system.cpu / 100
            detail: Math.round(panel.system.cpu) + "%" + (panel.temps.cpu ? " · " + Math.round(panel.temps.cpu) + "°C" : "")
        }

        // One bar per hardware thread, so idle cores are easy to spot.
        Row {
            id: strip
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(22)
            spacing: 2
            readonly property real barWidth: panel.cores.length
                ? (width - spacing * (panel.cores.length - 1)) / panel.cores.length : 0

            Repeater {
                model: panel.cores

                Item {
                    required property var modelData
                    width: strip.barWidth
                    height: parent.height

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.16)
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(2, parent.height * modelData / 100)
                        radius: 2
                        color: panel.tone(modelData / 100)

                        Behavior on height { NumberAnimation { duration: 250 } }
                    }
                }
            }
        }

        Meter {
            visible: panel.gpu.busy !== undefined
            label: "GPU"
            value: (panel.gpu.busy || 0) / 100
            detail: (panel.gpu.busy || 0) + "%" + (panel.temps.gpu ? " · " + Math.round(panel.temps.gpu) + "°C" : "")
        }

        Meter {
            visible: panel.gpu.vramTotal > 0
            label: "VRAM"
            value: AgentModel.fraction(panel.gpu.vramUsed, panel.gpu.vramTotal)
            detail: AgentModel.memText(panel.gpu.vramUsed) + " / " + AgentModel.memText(panel.gpu.vramTotal)
        }

        Meter {
            label: "RAM"
            value: AgentModel.fraction(panel.system.memUsed, panel.system.memTotal)
            detail: AgentModel.memText(panel.system.memUsed) + " / " + AgentModel.memText(panel.system.memTotal)
        }

        Text {
            Layout.fillWidth: true
            visible: panel.totals.count > 0
            text: "AI sessions: " + panel.totals.count + " running, "
                + AgentModel.cpuText(panel.totals.cpu) + ", " + AgentModel.memText(panel.totals.rssBytes)
            textFormat: Text.PlainText
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.55)
            color: Commons.Color.menu.text
            opacity: 0.7
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
        }
    }
}
