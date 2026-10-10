pragma ComponentBehavior: Bound

import qs.Modules.Common
import "annotation_tools.js" as AnnotationTools
import qs.Modules.Common.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

FloatingWindow {
    id: root

    property string imagePath: ""
    readonly property string localImagePath: imagePath.startsWith("file://")
        ? decodeURIComponent(imagePath.slice(7)) : imagePath
    property color strokeColor: "#ff3b30"
    property real strokeWidth: 3
    property bool rounded: false
    property string tool: "arrow"
    property var shapes: []
    signal cancelled()
    signal saved(string path, bool copied)
    signal saveFailed()
    title: "Annotate screenshot"
    color: "#1a1a1a"
    visible: true

    readonly property real toolbarH: 124
    readonly property var scr: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    readonly property real maxW: (scr?.width ?? 1920) * 0.9
    readonly property real maxH: (scr?.height ?? 1080) * 0.9

    implicitWidth: {
        if (sourceImage.status !== Image.Ready || sourceImage.sourceSize.width <= 0) return 900;
        const fit = Math.min(maxW / sourceImage.sourceSize.width,
                             (maxH - toolbarH) / sourceImage.sourceSize.height, 1);
        return Math.round(sourceImage.sourceSize.width * fit) + 32;
    }
    implicitHeight: {
        if (sourceImage.status !== Image.Ready || sourceImage.sourceSize.height <= 0) return 640;
        const fit = Math.min(maxW / sourceImage.sourceSize.width,
                             (maxH - toolbarH) / sourceImage.sourceSize.height, 1);
        return Math.round(sourceImage.sourceSize.height * fit) + 32 + toolbarH;
    }
    minimumSize: Qt.size(360, 280)

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
                root.changeSize(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Minus) {
                root.changeSize(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (textEditor.visible) {
                    root.cancelText();
                    event.accepted = true;
                } else {
                    root.cancelled();
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            id: stageArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                id: stage
                anchors.centerIn: parent

                property real scaleFactor: {
                    if (sourceImage.status !== Image.Ready
                        || sourceImage.sourceSize.width <= 0) return 1;
                    return Math.min((stageArea.width - 24) / sourceImage.sourceSize.width,
                                    (stageArea.height - 24) / sourceImage.sourceSize.height, 1);
                }
                width: sourceImage.sourceSize.width
                height: sourceImage.sourceSize.height
                scale: scaleFactor
                clip: true

                Image {
                    id: sourceImage
                    anchors.fill: parent
                    source: "file://" + root.localImagePath.split("/").map(encodeURIComponent).join("/")
                    fillMode: Image.Stretch
                    smooth: true
                    cache: false
                    onStatusChanged: {
                        if (status === Image.Error)
                            root.errorMessage = qsTr("Could not load the screenshot.")
                    }
                }

                Canvas {
                    id: canvas
                    anchors.fill: parent

                    function renderShapes(): void {
                        AnnotationTools.render(getContext("2d"), drawArea.preview
                            ? root.shapes.concat([drawArea.preview]) : root.shapes);
                    }

                    onPaint: renderShapes()
                }

                MouseArea {
                    id: drawArea
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    acceptedButtons: Qt.LeftButton

                    property var preview: null

                    function updatePreview(mouse): void {
                        AnnotationTools.update(preview, mouse.x, mouse.y,
                            !!(mouse.modifiers & Qt.ShiftModifier), stage.width, stage.height);
                        canvas.requestPaint();
                    }
                    onPressed: (mouse) => {
                        if (textEditor.visible) root.commitText();
                        keyHandler.forceActiveFocus();
                        if (root.tool === "text") return;
                        preview = AnnotationTools.create(root.tool, mouse.x, mouse.y,
                            root.strokeColor, root.strokeWidth, root.rounded);
                        canvas.requestPaint();
                    }
                    onPositionChanged: (mouse) => {
                        if (preview) updatePreview(mouse);
                    }
                    onReleased: (mouse) => {
                        if (root.tool === "text") { root.startText(mouse.x, mouse.y); return; }
                        if (!preview) return;
                        updatePreview(mouse);
                        root.shapes = root.shapes.concat([preview]);
                        preview = null;
                        canvas.requestPaint();
                    }
                    onCanceled: {
                        preview = null;
                        canvas.requestPaint();
                    }
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y !== 0)
                            root.changeSize(wheel.angleDelta.y > 0 ? 1 : -1);
                        wheel.accepted = true;
                    }
                }

                TextField {
                    id: textEditor
                    visible: false
                    color: root.strokeColor
                    font.pixelSize: 22
                    font.bold: true
                    background: Rectangle {
                        color: "#22ffffff"
                        border.color: root.strokeColor
                        border.width: 1
                        radius: 3
                    }
                    onAccepted: root.commitText()
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) { root.cancelText(); event.accepted = true; }
                    }
                }
            }
        }


        StyledText {
            Layout.fillWidth: true
            visible: root.errorMessage.length > 0
            text: root.errorMessage
            wrapMode: Text.WordWrap
            color: Appearance.m3colors.m3error
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.toolbarH
            color: "#22ffffff"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    contentWidth: Math.max(width, toolRow.implicitWidth)
                    contentHeight: 48
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    ScrollBar.horizontal: ScrollBar {}

                    RowLayout {
                        id: toolRow
                        x: (parent.width - width) / 2
                        spacing: 4
                        Repeater {
                            model: [
                                { tool: "pen", icon: "edit", label: qsTr("Freehand pen") },
                                { tool: "line", icon: "diagonal_line", label: qsTr("Straight line") },
                                { tool: "arrow", icon: "north_east", label: qsTr("Arrow") },
                                { tool: "rect", icon: "crop_square", label: qsTr("Outline rectangle") },
                                { tool: "fill", icon: "square", label: qsTr("Filled rectangle") },
                                { tool: "ellipse", icon: "circle", label: qsTr("Ellipse") },
                                { tool: "marker", icon: "ink_highlighter", label: qsTr("Highlighter") },
                                { tool: "text", icon: "title", label: qsTr("Text") }
                            ]
                            delegate: AnnotatorToolButton {
                                required property var modelData
                                filledIcon: modelData.tool === "fill"
                                icon: modelData.icon
                                label: modelData.label
                                active: root.tool === modelData.tool
                                onClicked: {
                                    if (textEditor.visible) root.commitText();
                                    root.tool = modelData.tool;
                                    keyHandler.forceActiveFocus();
                                }
                            }
                        }
                        CheckBox {
                            text: qsTr("Rounded")
                            visible: root.tool === "rect" || root.tool === "fill"
                            checked: root.rounded
                            onToggled: root.rounded = checked
                        }
                        AnnotatorToolButton {
                            icon: "content_copy"
                            label: qsTr("Save and copy file path")
                            enabled: !output.busy && canvas.available && sourceImage.status === Image.Ready
                            onClicked: root.saveAndCopy()
                        }
                        AnnotatorToolButton {
                            icon: "close"
                            label: qsTr("Cancel")
                            onClicked: root.cancelled()
                        }
                    }
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    contentWidth: Math.max(width, styleRow.implicitWidth)
                    contentHeight: 48
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    ScrollBar.horizontal: ScrollBar {}

                    RowLayout {
                        id: styleRow
                        x: (parent.width - width) / 2
                        spacing: 6
                        Repeater {
                            model: ["#ff3b30", "#ffff00", "#34c759", "#00bfff", "#af52de", "#ffffff", "#000000"]
                            delegate: Rectangle {
                                required property string modelData
                                implicitWidth: 28
                                implicitHeight: 28
                                radius: 14
                                color: modelData
                                border.width: root.strokeColor.toString() === modelData ? 3 : 1
                                border.color: root.strokeColor.toString() === modelData ? "#808080" : "#eeeeee"
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.strokeColor = parent.modelData
                                }
                            }
                        }
                        TextField {
                            id: customColor
                            Layout.preferredWidth: 104
                            text: root.strokeColor.toString()
                            placeholderText: "#RRGGBB"
                            maximumLength: 7
                            validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}/ }
                            onEditingFinished: {
                                if (acceptableInput) root.strokeColor = text;
                                text = Qt.binding(() => root.strokeColor.toString());
                            }
                        }
                        StyledText { text: qsTr("Size") }
                        SpinBox {
                            id: sizeControl
                            from: 1
                            to: 100
                            value: root.strokeWidth
                            editable: true
                            onValueModified: root.strokeWidth = value
                        }
                        StyledText {
                            text: root.tool === "marker" ? qsTr("× 10 px · Shift to constrain")
                                : qsTr("px · Shift to constrain")
                        }
                    }
                }
            }
        }
    }

    function changeSize(delta): void {
        strokeWidth = AnnotationTools.size(strokeWidth + delta);
    }

    function startText(x, y) {
        textEditor.text = "";
        textEditor.x = x;
        textEditor.y = y;
        textEditor.visible = true;
        textEditor.forceActiveFocus();
    }
    function commitText() {
        if (textEditor.text.length > 0) {
            root.shapes = root.shapes.concat([{
                type: "text", x1: textEditor.x, y1: textEditor.y,
                text: textEditor.text, color: root.strokeColor.toString(),
                width: root.strokeWidth, opacity: 1
            }]);
        }
        textEditor.visible = false;
        textEditor.text = "";
        canvas.requestPaint();
        keyHandler.forceActiveFocus();
    }
    function cancelText() {
        textEditor.visible = false;
        textEditor.text = "";
        keyHandler.forceActiveFocus();
    }

    required property string renderedPath
    property string errorMessage: ""
    onClosed: root.cancelled()

    function saveAndCopy(): void {
        if (output.busy || !canvas.available || sourceImage.status !== Image.Ready)
            return
        if (textEditor.visible)
            commitText()
        errorMessage = ""
        // Include pending text without waiting for the next preview frame.
        canvas.renderShapes()
        // An explicit save size crops the DPR-sized buffer on scaled displays.
        if (!canvas.save(renderedPath)) {
            console.warn("[ScreenshotEditor] Could not render annotation layer:", renderedPath)
            errorMessage = qsTr("Could not render the screenshot. Please try again.")
            root.saveFailed()
            return
        }
        const dot = localImagePath.lastIndexOf(".")
        const stem = dot > localImagePath.lastIndexOf("/") ? localImagePath.slice(0, dot) : localImagePath
        const timestamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH.mm.ss.zzz")
        output.saveFile(renderedPath, `${stem}_annotated_${timestamp}.png`)
    }

    ScreenshotOutput {
        id: output
        backgroundPath: root.localImagePath
        onFinished: (path, copied) => {
            root.saved(path, copied)
        }
        onFailed: message => {
            root.saveFailed()
            root.errorMessage = message
        }
    }

    component AnnotatorToolButton: Rectangle {
        id: btn
        property string icon: ""
        property string label: ""
        property bool active: false
        property bool filledIcon: false
        signal clicked()
        implicitWidth: 48
        implicitHeight: 48
        radius: Appearance?.rounding?.small ?? 8
        color: btn.active ? "#556677"
            : (mouse.containsMouse ? "#33ffffff" : "#22ffffff")
        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 24
            text: btn.icon
            fill: btn.filledIcon ? 1 : 0
            color: btn.active ? "#ffffff" : "#eeeeee"
        }
        ToolTip.visible: mouse.containsMouse
        ToolTip.text: btn.label
        ToolTip.delay: 500
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
