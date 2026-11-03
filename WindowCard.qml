import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Wayland
import "WindowModel.js" as WindowModel
import "AgentModel.js" as AgentModel
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

Ui.BorderSurface {
    id: card

    required property var modelData
    required property var controller
    required property var screenToplevels
    required property bool acceptsKeyboard
    required property var windowLayout
    required property real layoutAreaWidth
    required property real layoutAreaHeight
    // Position in the filtered list; -1 hides the card.
    readonly property int slot: card.screenToplevels.indexOf(modelData)
    readonly property bool inLayout: slot >= 0
    property bool hovered: false
    onHoveredChanged: {
        if (card.hovered) {
            card.hoverNow = Date.now() / 1000;
            hoverDelay.restart();
        } else {
            hoverDelay.stop();
            card.hoverCardShown = false;
        }
    }
    readonly property bool selected: card.acceptsKeyboard && inLayout && slot === card.controller.selectedIndex
    readonly property bool focusedWindow: modelData === Hyprland.activeToplevel
    readonly property bool previewed: card.acceptsKeyboard && inLayout && slot === card.controller.previewIndex
    readonly property bool exitingPreview: card.acceptsKeyboard && inLayout && slot === card.controller.previewExitIndex
    readonly property bool floatingFooter: card.controller.windowFooterStyle === "floating"
    readonly property bool integratedFooter: card.controller.windowFooterStyle === "integrated"
    readonly property bool overlayFooter: card.controller.windowFooterStyle === "overlay"
    readonly property bool centeredFooter: card.controller.windowFooterStyle === "centered"
    readonly property var agentInfo: card.controller.agentInfoFor(modelData)
    readonly property string agentName: String(card.agentInfo.agent || "")
    readonly property string agentState: card.agentName ? AgentModel.stateFromTitle(modelData.title) : ""
    readonly property bool terminalWindow: card.agentName !== "" || AgentModel.isTerminalClass(WindowModel.appIdFor(modelData))
    readonly property string workingDirectory: card.terminalWindow
        ? AgentModel.shortPath(card.agentInfo.cwd, card.controller.homeDirectory) : ""
    readonly property string windowTitle: card.agentName
        ? AgentModel.cleanTitle(String(modelData.title || "Untitled window"))
        : String(modelData.title || WindowModel.appIdFor(modelData) || "Untitled window")
    // Second footer line: the state (agents only), then folder and git branch.
    // The logo already says which agent it is; hovering shows the rest.
    readonly property string folderLine: {
        var folder = AgentModel.folderName(card.agentInfo.cwd, card.controller.homeDirectory);
        var branch = String(card.agentInfo.branch || "");
        return folder ? folder + (branch ? "  ⎇ " + branch : "") : "";
    }
    readonly property string detailLine: {
        var parts = [];
        if (card.agentState === "waiting")
            parts.push("waits for you");
        else if (card.agentState === "working")
            parts.push("working");
        if (card.terminalWindow && card.folderLine)
            parts.push(card.folderLine);
        return parts.join("  ·  ");
    }
    // Hover details, one "label  value" row each.
    readonly property var detailRows: {
        var rows = [];
        if (card.agentName)
            rows.push(["Agent", AgentModel.labelFor(card.agentName)
                + (card.agentState === "waiting" ? " · waits for you" : (card.agentState === "working" ? " · working" : ""))]);
        if (card.terminalWindow && card.agentInfo.cwd && String(card.agentInfo.cwd).indexOf("/proc/") !== 0)
            rows.push(["Directory", AgentModel.shortPath(card.agentInfo.cwd, card.controller.homeDirectory, true)]);
        if (card.agentInfo.branch)
            rows.push(["Branch", String(card.agentInfo.branch)]);
        var age = card.terminalWindow ? AgentModel.durationText(card.agentInfo.started, card.hoverNow) : "";
        if (age)
            rows.push([card.agentName ? "Running for" : "Open for", age]);
        rows.push(["Application", card.applicationName]);
        rows.push(["Workspace", card.workspaceName]);
        return rows;
    }
    property real hoverNow: Date.now() / 1000
    property bool hoverCardShown: false
    readonly property string applicationName: WindowModel.appIdFor(modelData) || "Application"
    readonly property string workspaceName: card.controller.workspaceName(modelData)
    readonly property string iconSource: card.agentName
        ? Qt.resolvedUrl("assets/agents/" + (["claude", "codex"].indexOf(card.agentName) !== -1 ? card.agentName : "agent") + ".svg")
        : card.controller.iconFor(modelData)
    readonly property var outlineSpec: hovered || selected || focusedWindow
        ? controller.windowBorders.activeSpec : controller.windowBorders.inactiveSpec
    readonly property color currentColor: Style.selectedStateColor(Commons.Color.menu.text, Commons.Color.accent)
    // An excluded card keeps its last rectangle, so it neither
    // animates toward the origin nor flies back in from it.
    readonly property var packedRectSource: inLayout ? card.windowLayout[slot] : null
    property var packedRect: Qt.rect(0, 0, 1, 1)
    readonly property var previewRect: card.controller.previewRectFor(modelData, packedRect, card.layoutAreaWidth, card.layoutAreaHeight, Style.spacing.sm, card.controller.windowFooterHeight)
    readonly property var layoutRect: previewed ? previewRect : packedRect

    onPackedRectSourceChanged: {
        if (packedRectSource)
            packedRect = packedRectSource;

    }
    Component.onCompleted: {
        if (packedRectSource)
            packedRect = packedRectSource;

    }
    visible: inLayout
    x: layoutRect.x
    y: layoutRect.y
    width: layoutRect.width
    height: layoutRect.height
    z: previewed ? 11 : (exitingPreview ? 10 : 0)
    radius: integratedFooter ? Style.cornerRadius : 0
    color: integratedFooter ? Commons.Color.menu.background : "transparent"
    borderSpec: integratedFooter ? outlineSpec : Border.none()
    opacity: card.controller.previewIndex < 0 || previewed ? 1 : 0.28

    MouseArea {
        anchors.fill: parent
        enabled: !card.controller.settingsOpen && (card.controller.previewIndex < 0 || card.previewed)
        hoverEnabled: true
        onEnabledChanged: {
            if (!enabled) {
                card.hovered = false;
                if (card.controller.hoveredIndex === card.slot)
                    card.controller.hoveredIndex = -1;

            }
        }
        onEntered: {
            card.hovered = true;
            if (card.acceptsKeyboard) {
                card.controller.hoveredIndex = card.slot;
                card.controller.selectedIndex = card.slot;
            }
        }
        onExited: {
            card.hovered = false;
            if (card.acceptsKeyboard && card.controller.hoveredIndex === card.slot)
                card.controller.hoveredIndex = -1;

        }
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton)
                card.controller.requestClose(card.modelData);
            else
                card.controller.activate(card.modelData);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.spacing.sm
        spacing: card.overlayFooter ? 0 : Style.spacing.sm

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: previewFrame

                readonly property real windowAspectRatio: card.controller.aspectRatioFor(card.modelData)

                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height * windowAspectRatio)
                height: Math.min(parent.height, parent.width / windowAspectRatio)
                radius: Math.max(0, Style.cornerRadius - Style.spacing.xs)
                color: Commons.Color.background
                clip: true
                layer.enabled: true

                CardText {
                    anchors.centerIn: parent
                    text: "Live preview unavailable"
                    opacity: 0.45
                }

                Item {
                    anchors.centerIn: parent
                    width: parent.width * 2
                    height: parent.height * 2
                    scale: 0.5
                    layer.enabled: true
                    layer.smooth: true

                    ScreencopyView {
                        anchors.fill: parent
                        captureSource: WindowModel.waylandFor(card.modelData)
                        live: card.controller.opened && card.inLayout
                        paintCursor: false
                    }

                }

                Loader {
                    anchors.fill: parent
                    z: 2
                    active: card.overlayFooter
                    sourceComponent: overlayFooterComponent
                }

                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: previewMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

            }

            Ui.BorderSurface {
                anchors.fill: previewFrame
                visible: !card.integratedFooter
                z: 5
                radius: previewFrame.radius
                color: "transparent"
                borderSpec: card.outlineSpec
            }

            Rectangle {
                id: previewMask

                anchors.fill: previewFrame
                radius: previewFrame.radius
                color: "black"
                visible: false
                layer.enabled: true
                layer.smooth: true
            }

        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(40)
            visible: !card.overlayFooter

            Loader {
                anchors.fill: parent
                sourceComponent: card.floatingFooter ? floatingFooterComponent : (card.integratedFooter ? integratedFooterComponent : (card.centeredFooter ? centeredFooterComponent : null))
            }

        }

    }

    // Shared footer building blocks; each footer style overrides only what differs.
    component CardText: Text {
        textFormat: Text.PlainText
        color: Commons.Color.menu.text
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
    }

    component FooterTitle: CardText {
        text: card.windowTitle
        font.bold: card.selected
        elide: Text.ElideRight
    }

    component FooterIcon: Image {
        property int iconSize: 24
        Layout.preferredWidth: Style.space(iconSize)
        Layout.preferredHeight: Style.space(iconSize)
        source: card.iconSource
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: Style.space(iconSize) * 2
        sourceSize.height: Style.space(iconSize) * 2

        Rectangle {
            visible: card.agentState === "waiting"
            width: Style.space(9)
            height: width
            radius: width / 2
            color: "#F5C451"
            anchors.right: parent.right
            anchors.top: parent.top
        }
    }

    component WorkspaceColumn: ColumnLayout {
        spacing: 0

        CardText {
            Layout.alignment: Qt.AlignRight
            text: card.workspaceName
            color: card.focusedWindow ? card.currentColor : Commons.Color.menu.text
            font.pixelSize: Style.font.heading
            font.bold: true
        }

        CardText {
            Layout.alignment: Qt.AlignRight
            visible: card.width > Style.space(420)
            text: "Workspace"
            opacity: 0.55
            font.pixelSize: Style.font.caption
        }
    }

    // Only the configured footer style is instantiated per card.
    Component {
        id: overlayFooterComponent

        Item {
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.min(parent.height * 0.45, Style.space(84))

                gradient: Gradient {
                    orientation: Gradient.Vertical

                    GradientStop {
                        position: 0
                        color: "transparent"
                    }

                    GradientStop {
                        position: 1
                        color: Commons.Color.menu.background
                    }
                }
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Style.spacing.md
                spacing: Style.spacing.md

                FooterIcon { iconSize: 28 }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    FooterTitle { Layout.fillWidth: true }

                    CardText {
                        Layout.fillWidth: true
                        text: card.detailLine || card.applicationName
                        opacity: 0.68
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }
                }

                WorkspaceColumn {}
            }
        }
    }

    Component {
        id: floatingFooterComponent

        RowLayout {
            spacing: Style.spacing.md

            FooterIcon { iconSize: 30 }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                FooterTitle { Layout.fillWidth: true }

                CardText {
                    Layout.fillWidth: true
                    text: card.detailLine || card.applicationName
                    opacity: 0.62
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                }
            }

            WorkspaceColumn {}
        }
    }

    Component {
        id: integratedFooterComponent

        RowLayout {
            spacing: Style.spacing.md

            FooterIcon {}

            FooterTitle { Layout.fillWidth: true }

            CardText {
                text: "WS " + card.workspaceName
                color: card.focusedWindow ? card.currentColor : Commons.Color.menu.text
                opacity: card.focusedWindow ? 1 : 0.68
                font.pixelSize: Style.font.caption
                font.bold: true
            }
        }
    }

    Component {
        id: centeredFooterComponent

        ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Style.spacing.md

                FooterIcon {}

                FooterTitle { Layout.maximumWidth: Math.max(1, card.width - Style.space(80)) }
            }

            CardText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: Math.max(1, card.width - Style.space(32))
                text: (card.detailLine || card.applicationName) + "  ·  Workspace " + card.workspaceName
                color: card.focusedWindow ? card.currentColor : Commons.Color.menu.text
                opacity: card.focusedWindow ? 1 : 0.62
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
            }
        }
    }

    Timer {
        id: hoverDelay
        interval: 450
        onTriggered: card.hoverCardShown = card.hovered && card.controller.previewIndex < 0
    }

    // Details on hover, drawn over the bottom of the preview.
    Rectangle {
        id: hoverCard
        visible: card.hoverCardShown && card.inLayout
        z: 20
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: card.controller.windowFooterHeight + Style.spacing.sm
        width: Math.min(card.width - Style.spacing.md * 2, Style.space(360))
        height: hoverRows.implicitHeight + Style.spacing.md * 2
        radius: Style.cornerRadius
        color: Commons.Color.menu.background
        border.width: 1
        border.color: Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g, Commons.Color.menu.text.b, 0.25)

        ColumnLayout {
            id: hoverRows
            anchors.fill: parent
            anchors.margins: Style.spacing.md
            spacing: Style.spacing.sm

            CardText {
                Layout.fillWidth: true
                text: AgentModel.cleanTitle(String(card.modelData.title || ""))
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Repeater {
                model: card.detailRows

                RowLayout {
                    id: detailRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Style.spacing.md

                    CardText {
                        Layout.preferredWidth: Style.space(92)
                        text: detailRow.modelData[0]
                        opacity: 0.55
                        font.pixelSize: Style.font.caption
                    }

                    CardText {
                        Layout.fillWidth: true
                        text: detailRow.modelData[1]
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideMiddle
                    }
                }
            }
        }
    }

    Behavior on x {
        enabled: card.controller.motionSettled

        NumberAnimation {
            duration: card.controller.previewAnimationDuration
            easing.type: card.controller.previewAnimationEasing
        }

    }

    Behavior on y {
        enabled: card.controller.motionSettled

        NumberAnimation {
            duration: card.controller.previewAnimationDuration
            easing.type: card.controller.previewAnimationEasing
        }

    }

    Behavior on width {
        enabled: card.controller.motionSettled

        NumberAnimation {
            duration: card.controller.previewAnimationDuration
            easing.type: card.controller.previewAnimationEasing
        }

    }

    Behavior on height {
        enabled: card.controller.motionSettled

        NumberAnimation {
            duration: card.controller.previewAnimationDuration
            easing.type: card.controller.previewAnimationEasing
        }

    }

    Behavior on opacity {
        enabled: card.controller.motionSettled

        NumberAnimation {
            duration: card.controller.previewFadeDuration
        }

    }

}
