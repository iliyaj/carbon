pragma ComponentBehavior: Bound

import qs.Modules.Common
import "annotation_tools.js" as AnnotationTools
import "annotation_editing.js" as AnnotationEditing
import "screenshot_preferences.js" as ScreenshotPreferences
import "screenshot_precision.js" as ScreenshotPrecision
import qs.Modules.Common.Widgets
import qs.Services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

FloatingWindow {
    id: root

    property string imagePath: ""
    property bool automation: false
    signal accepted()
    readonly property string localImagePath: imagePath.startsWith("file://")
        ? decodeURIComponent(imagePath.slice(7)) : imagePath
    property color strokeColor: ConfigOptions.screenshot.color
    property real strokeWidth: ConfigOptions.screenshot.strokeWidth
    property bool rounded: ConfigOptions.screenshot.rounded
    property string tool: ConfigOptions.screenshot.defaultTool
    readonly property string activeType: selectedShape?.type ?? tool
    readonly property string renderSource: sourceImage.source + "?render=" + Date.now() // bypass the canvas pixmap cache
    property bool renderLoaded: false
    readonly property bool renderReady: renderLoaded && canvas.available
        && sourceImage.status === Image.Ready && sourceImage.sourceSize.width > 0 && sourceImage.sourceSize.height > 0
    property var editHistory: AnnotationEditing.history([], 1)
    readonly property var shapes: editHistory.present.shapes
    readonly property int nextCounter: editHistory.present.nextCounter
    property int selectedIndex: -1
    readonly property var selectedShape: shapes[selectedIndex] ?? null
    property var gesture: null
    readonly property var selectedPreview: gesture && (gesture.kind === "move" || gesture.kind === "resize" || gesture.kind === "endpoint")
        ? gesture.preview : selectedShape
    readonly property var selectionBounds: selectedPreview
        ? AnnotationEditing.controlBounds(selectedPreview, shapeDetail(selectedPreview)) : null
    readonly property var selectionHandles: selectedPreview ? handlePoints(selectedPreview) : []
    property bool showObjects: false
    property bool showOptions: true
    property bool magnifier: ConfigOptions.screenshot.magnifier
    property bool sampleMode: false
    property var inspectedPixel: null
    property point pointerPosition: Qt.point(0, 0)
    readonly property color uiBackground: ConfigOptions.screenshot.contrast === "high" ? "#181818" : Appearance.m3colors.m3surfaceContainer
    readonly property color uiForeground: ConfigOptions.screenshot.contrast === "high" ? "#ffffff" : Appearance.m3colors.m3onSurface
    property var textFormat: ({ family: ConfigOptions.screenshot.fontFamily || Appearance.font.family.main,
        size: ConfigOptions.screenshot.fontSize, bold: ConfigOptions.screenshot.fontBold, italic: ConfigOptions.screenshot.fontItalic,
        underline: ConfigOptions.screenshot.fontUnderline, strikeout: ConfigOptions.screenshot.fontStrikeout, align: ConfigOptions.screenshot.fontAlign })
    property var pendingText: null
    property int pendingTextIndex: -1
    readonly property bool textMode: tool === "text" || pendingText !== null || selectedShape?.type === "text"
    signal cancelled()
    signal saved(string path, bool copied)
    signal saveFailed()
    signal loadFailed(string message)
    readonly property size imageSize: sourceImage.sourceSize
    title: "Annotate screenshot"
    color: uiBackground
    visible: true

    readonly property real toolbarH: showOptions ? 176 : 124
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
    minimumSize: Qt.size(360, 336)

    Component.onCompleted: {
        const previous = PersistentStates.screenshot.lastStyle;
        if (ConfigOptions.screenshot.rememberStyle && previous) {
            try {
                ScreenshotPreferences.validate({ defaultTool: previous.tool, color: previous.color,
                    strokeWidth: previous.width, rounded: previous.rounded, fontFamily: previous.font.family,
                    fontSize: previous.font.size, fontAlign: previous.font.align });
                tool = previous.tool; strokeColor = previous.color; strokeWidth = previous.width;
                rounded = previous.rounded; textFormat = Object.assign({}, textFormat, previous.font);
            } catch (error) { /* Ignore obsolete or invalid runtime history. */ }
        }
        if (ConfigOptions.screenshot.showHelp) Qt.callLater(() => helpDialog.open());
    }

    function shortcutLabel(action, label): string {
        const key = ScreenshotPreferences.bindings(ConfigOptions.screenshot.shortcuts)[action];
        return label + (key ? " (" + key + ")" : "");
    }

    function handleAction(action): bool {
        if (!action) return false;
        if (ScreenshotPreferences.tools.includes(action)) activateTool(action);
        else if (action === "undo") undoEdit();
        else if (action === "redo") redoEdit();
        else if (action === "delete") deleteSelection();
        else if (action === "editText") editSelectedText();
        else if (action === "commitText") { if (pendingText) commitText(); else if (automation) accepted(); }
        else if (action === "larger") changeSize(1);
        else if (action === "smaller") changeSize(-1);
        else if (action === "objects") showObjects = !showObjects;
        else if (action === "options") showOptions = !showOptions;
        else if (action === "help") helpDialog.open();
        else if (action === "sample") sampleMode = !sampleMode;
        else if (action === "magnifier") magnifier = !magnifier;
        else if (action === "copy") exportActions.requestCopy();
        else if (action === "save") exportActions.requestSave("save");
        else if (action === "saveAs") exportActions.saveAs();
        else if (action === "saveCopy") exportActions.requestSave("save-copy");
        else if (action === "copyPath") exportActions.copyPath();
        else if (action === "outputOptions") exportActions.showOptions();
        else if (action === "rounded") setRounded(!rounded);
        else if (action === "pin") exportScreenshot("pin", "", exportActions.options());
        else if (action === "open") exportActions.openWith();
        else if (action === "cancel") {
            if (sampleMode) sampleMode = false;
            else if (gesture) cancelGesture();
            else if (pendingText) cancelText();
            else cancelEditor();
        } else if (/^(left|right|up|down|resize|symmetric)/.test(action)) moveObject(action);
        else return false;
        return true;
    }

    function moveObject(action): void {
        if (!selectedShape || gesture || pendingText) return;
        const before = shapeBounds(selectedShape);
        const after = ScreenshotPrecision.keyboardRegion(before, action, stage.width, stage.height, 1);
        let shape;
        if (action.startsWith("resize") || action.startsWith("symmetric")) {
            if (selectedShape.type === "text" || selectedShape.type === "counter") return;
            shape = AnnotationEditing.resize(selectedShape, before, after);
        } else shape = AnnotationEditing.move(selectedShape, after.x - before.x, after.y - before.y, before, stage.width, stage.height);
        const next = shapes.slice(); next[selectedIndex] = shape;
        applyObjects(next, nextCounter);
    }

    function inspectPixel(x, y): void {
        if (!renderReady) return;
        canvas.renderShapes(true);
        inspectedPixel = ScreenshotPrecision.pixels(canvas.getContext("2d"), x, y, stage.width, stage.height);
        pointerPosition = stage.mapToItem(stageArea, x, y);
        canvas.requestPaint();
    }

    Dialog {
        id: helpDialog
        parent: Overlay.overlay
        title: qsTr("Screenshot shortcuts")
        modal: true
        x: (parent.width - width) / 2; y: (parent.height - height) / 2
        width: Math.min(520, parent.width - 24); height: Math.min(600, parent.height - 24)
        standardButtons: Dialog.Close
        contentItem: ScrollView {
            clip: true
            ColumnLayout {
                width: helpDialog.availableWidth - 20
                Label {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: qsTr("Shift constrains drawing. Arrow keys move a selected object; Shift resizes shapes and Ctrl+Shift resizes symmetrically. The magnifier and sampler use source pixels plus committed annotations, excluding drafts, handles and the cursor. Text fields keep their normal typing and clipboard keys. Remap local keys in Settings → Screenshots.")
                }
                Repeater {
                    model: Object.keys(ScreenshotPreferences.shortcuts)
                    delegate: Label {
                        required property string modelData
                        text: root.shortcutLabel(modelData, modelData)
                    }
                }
            }
        }
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const action = ScreenshotPreferences.action(event, ConfigOptions.screenshot.shortcuts, Qt);
            if (root.handleAction(action)) event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                id: stageArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    id: stage
                    objectName: "annotationStage"
                    anchors.centerIn: parent

                    property real scaleFactor: {
                        if (sourceImage.status !== Image.Ready
                            || sourceImage.sourceSize.width <= 0) return 1;
                        return Math.max(0.01, Math.min((stageArea.width - 24) / sourceImage.sourceSize.width,
                                        (stageArea.height - 24) / sourceImage.sourceSize.height, 1));
                    }
                    width: sourceImage.sourceSize.width
                    height: sourceImage.sourceSize.height
                    scale: scaleFactor
                    clip: true

                    Image {
                        id: sourceImage
                        visible: false // Canvas owns source rendering; this Image supplies dimensions and status.
                        source: "file://" + root.localImagePath.split("/").map(encodeURIComponent).join("/")
                        cache: false
                        onStatusChanged: {
                            if (status === Image.Error) {
                                root.errorMessage = qsTr("Could not load the screenshot.")
                                root.loadFailed(root.errorMessage)
                            }
                        }
                    }

                    Canvas {
                        id: canvas
                        objectName: "annotationCanvas"
                        width: stage.width / root.devicePixelRatio // one buffer pixel per source pixel
                        height: stage.height / root.devicePixelRatio
                        scale: root.devicePixelRatio
                        transformOrigin: Item.TopLeft
                        Component.onCompleted: loadImage(root.renderSource)
                        onImageLoaded: {
                            root.renderLoaded = isImageLoaded(root.renderSource);
                            requestPaint();
                        }

                        function renderShapes(committed = false): void {
                            if (!root.renderLoaded) {
                                getContext("2d").reset();
                                return;
                            }
                            let list = root.shapes;
                            if (root.pendingText && !committed) {
                                list = list.slice();
                                if (root.pendingTextIndex >= 0) list[root.pendingTextIndex] = root.pendingText;
                                else list.push(root.pendingText);
                            }
                            if (root.gesture && !committed) {
                                list = list.slice();
                                if (root.gesture.kind === "draw") list.push(root.gesture.preview);
                                else list[root.gesture.index] = root.gesture.preview;
                            }
                            AnnotationTools.render(getContext("2d"), list, root.renderSource,
                                stage.width, stage.height, 1 / root.devicePixelRatio);
                        }

                        onPaint: renderShapes()
                    }

                    Rectangle {
                        visible: root.selectionBounds !== null && root.pendingText === null
                        x: root.selectionBounds?.x ?? 0
                        y: root.selectionBounds?.y ?? 0
                        width: root.selectionBounds?.width ?? 0
                        height: root.selectionBounds?.height ?? 0
                        color: "transparent"
                        border.color: "#00bfff"
                        border.width: 1 / stage.scaleFactor
                    }
                    Repeater {
                        model: root.pendingText === null ? root.selectionHandles : []
                        delegate: Rectangle {
                            required property var modelData
                            width: 8 / stage.scaleFactor
                            height: width
                            x: modelData.x - width / 2
                            y: modelData.y - height / 2
                            color: "#ffffff"
                            border.color: "#00bfff"
                            border.width: 1 / stage.scaleFactor
                        }
                    }

                    MouseArea {
                        id: drawArea
                        objectName: "annotationPointer"
                        anchors.fill: parent
                        cursorShape: root.sampleMode ? Qt.CrossCursor : root.tool === "select" ? Qt.ArrowCursor
                            : root.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: true

                        onPressed: mouse => {
                            if (root.sampleMode) {
                                root.inspectPixel(mouse.x, mouse.y);
                                if (root.inspectedPixel) root.setColor(root.inspectedPixel.color);
                                root.sampleMode = false;
                                return;
                            }
                            root.beginGesture(mouse.x, mouse.y, mouse.modifiers);
                        }
                        onPositionChanged: mouse => {
                            if (root.magnifier || root.sampleMode) root.inspectPixel(mouse.x, mouse.y);
                            root.updateGesture(mouse.x, mouse.y, mouse.modifiers);
                        }
                        onReleased: mouse => root.finishGesture(mouse.x, mouse.y, mouse.modifiers)
                        onCanceled: root.cancelGesture()
                        onDoubleClicked: {
                            if (root.tool === "select") root.editSelectedText();
                        }
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y !== 0)
                                root.changeSize(wheel.angleDelta.y > 0 ? 1 : -1);
                            wheel.accepted = true;
                        }
                    }

                    // The canvas draws pending text; this transparent editor supplies caret, selection and input.
                    TextArea {
                        id: textEditor
                        objectName: "annotationTextInput"
                        visible: root.pendingText !== null
                        x: root.pendingText?.x1 ?? 0
                        y: root.pendingText?.y1 ?? 0
                        width: Math.max(2, (root.pendingText?.x2 ?? 0) - x)
                        padding: 0
                        leftInset: -6 / stage.scaleFactor
                        rightInset: -6 / stage.scaleFactor
                        topInset: -4 / stage.scaleFactor
                        bottomInset: -4 / stage.scaleFactor
                        wrapMode: TextEdit.NoWrap
                        textFormat: TextEdit.PlainText
                        horizontalAlignment: root.textFormat.align === "center" ? TextEdit.AlignHCenter
                            : root.textFormat.align === "right" ? TextEdit.AlignRight : TextEdit.AlignLeft
                        font: Qt.font({ family: root.textFormat.family, pixelSize: root.textFormat.size,
                            bold: root.textFormat.bold, italic: root.textFormat.italic })
                        color: "transparent"
                        selectedTextColor: "transparent"
                        selectionColor: "#5533aaff"
                        cursorDelegate: Rectangle {
                            width: Math.max(1, 2 / stage.scaleFactor)
                            color: root.strokeColor
                        }
                        background: Rectangle {
                            color: "transparent"
                            border.color: root.strokeColor
                            border.width: 1 / stage.scaleFactor
                            radius: 3 / stage.scaleFactor
                        }
                        onTextChanged: root.refreshPendingText()
                        Keys.onPressed: (event) => {
                            const action = ScreenshotPreferences.action(event, ConfigOptions.screenshot.shortcuts, Qt);
                            if (action === "cancel") {
                                root.cancelText();
                                event.accepted = true;
                            } else if (action === "commitText") {
                                root.commitText();
                                event.accepted = true;
                            }
                        }
                    }
                }

                PixelMagnifier {
                    visible: (root.magnifier || root.sampleMode) && drawArea.containsMouse && root.inspectedPixel !== null
                    pixel: root.inspectedPixel
                    x: Math.max(0, Math.min(stageArea.width - width, root.pointerPosition.x + 24 + width <= stageArea.width
                        ? root.pointerPosition.x + 24 : root.pointerPosition.x - width - 24))
                    y: Math.max(0, Math.min(stageArea.height - height, root.pointerPosition.y + 24))
                }

                Row {
                    visible: textEditor.visible
                    spacing: 4
                    x: Math.min(stageArea.width - width, Math.max(0, stage.x + stage.width / 2
                        + (textEditor.x + textEditor.width - stage.width / 2) * stage.scaleFactor - width))
                    y: Math.min(stageArea.height - height, stage.y + stage.height / 2
                        + (textEditor.y + textEditor.height - stage.height / 2) * stage.scaleFactor + 8)

                    AnnotatorToolButton {
                        implicitWidth: 34
                        implicitHeight: 34
                        icon: "check"
                        label: qsTr("Finish text (Ctrl+Enter)")
                        onClicked: root.commitText()
                    }
                    AnnotatorToolButton {
                        implicitWidth: 34
                        implicitHeight: 34
                        icon: "close"
                        label: qsTr("Discard text (Esc)")
                        onClicked: root.cancelText()
                    }
                }
            }

            AnnotationObjects {
                objectName: "annotationObjects"
                visible: root.showObjects
                Layout.preferredWidth: Math.min(208, root.width * 0.4)
                Layout.fillHeight: true
                shapes: root.shapes
                selectedIndex: root.selectedIndex
                onSelectionRequested: index => root.selectObject(index)
                onEditRequested: root.editSelectedText()
                onDeleteRequested: root.deleteSelection()
                onReorderRequested: direction => root.reorderSelection(direction)
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
            color: Appearance.m3colors.m3surfaceContainerHigh

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
                                { tool: "select", icon: "arrow_selector_tool", label: qsTr("Select, move and resize") },
                                { tool: "pen", icon: "edit", label: qsTr("Freehand pen") },
                                { tool: "line", icon: "diagonal_line", label: qsTr("Straight line") },
                                { tool: "arrow", icon: "north_east", label: qsTr("Arrow") },
                                { tool: "rect", icon: "crop_square", label: qsTr("Outline rectangle") },
                                { tool: "fill", icon: "square", label: qsTr("Filled rectangle") },
                                { tool: "ellipse", icon: "circle", label: qsTr("Ellipse") },
                                { tool: "marker", icon: "ink_highlighter", label: qsTr("Highlighter") },
                                { tool: "text", icon: "title", label: qsTr("Text") },
                                { tool: "counter", icon: "counter_1", label: qsTr("Numbered pointer") },
                                { tool: "conceal", icon: "grid_on", label: qsTr("Conceal with opaque pixels (ignores covered content)") },
                                { tool: "pixelate", icon: "grid_4x4", label: qsTr("Pixelate (visual effect, may stay readable)") },
                                { tool: "blur", icon: "blur_on", label: qsTr("Blur (visual effect, may stay readable)") },
                                { tool: "solid", icon: "visibility_off", label: qsTr("Solid redaction") },
                                { tool: "invert", icon: "invert_colors", label: qsTr("Invert colours") }
                            ].filter(item => ConfigOptions.screenshot.toolOrder.includes(item.tool))
                                .sort((a, b) => ConfigOptions.screenshot.toolOrder.indexOf(a.tool) - ConfigOptions.screenshot.toolOrder.indexOf(b.tool))
                            delegate: AnnotatorToolButton {
                                required property var modelData
                                filledIcon: modelData.tool === "fill"
                                icon: modelData.icon
                                label: root.shortcutLabel(modelData.tool, modelData.label)
                                active: root.tool === modelData.tool
                                onClicked: {
                                    root.activateTool(modelData.tool);
                                }
                            }
                        }
                        AnnotatorToolButton {
                            icon: "undo"
                            label: root.shortcutLabel("undo", qsTr("Undo"))
                            enabled: root.editHistory.past.length > 0 || root.pendingText !== null || root.gesture !== null
                            onClicked: root.undoEdit()
                        }
                        AnnotatorToolButton {
                            icon: "redo"
                            label: root.shortcutLabel("redo", qsTr("Redo"))
                            enabled: root.editHistory.future.length > 0
                            onClicked: root.redoEdit()
                        }
                        AnnotatorToolButton {
                            icon: "layers"
                            label: root.shortcutLabel("objects", qsTr("Annotations"))
                            active: root.showObjects
                            onClicked: root.showObjects = !root.showObjects
                        }
                        AnnotatorToolButton {
                            icon: "tune"; label: root.shortcutLabel("options", qsTr("Tool options"))
                            active: root.showOptions; onClicked: root.showOptions = !root.showOptions
                        }
                        AnnotatorToolButton {
                            icon: "colorize"; label: root.shortcutLabel("sample", qsTr("Sample composited pixel"))
                            active: root.sampleMode; onClicked: root.sampleMode = !root.sampleMode
                        }
                        AnnotatorToolButton {
                            icon: "zoom_in"; label: root.shortcutLabel("magnifier", qsTr("Pixel magnifier"))
                            active: root.magnifier; onClicked: root.magnifier = !root.magnifier
                        }
                        AnnotatorToolButton {
                            icon: "help"; label: root.shortcutLabel("help", qsTr("Shortcut help")); onClicked: helpDialog.open()
                        }
                        CheckBox {
                            text: qsTr("Rounded")
                            visible: root.activeType === "rect" || root.activeType === "fill"
                            checked: root.rounded
                            onToggled: root.setRounded(checked)
                        }
                        AnnotatorToolButton {
                            icon: "close"
                            label: root.shortcutLabel("cancel", qsTr("Cancel"))
                            onClicked: root.cancelEditor()
                        }
                        AnnotatorToolButton {
                            visible: root.automation
                            icon: "check"
                            label: qsTr("Finish automation request")
                            enabled: root.renderReady && !root.exporting
                            onClicked: root.accepted()
                        }
                    }
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    visible: root.showOptions
                    contentWidth: Math.max(width, styleRow.implicitWidth)
                    contentHeight: 48
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    ScrollBar.horizontal: ScrollBar {}

                    RowLayout {
                        id: styleRow
                        x: Math.max(0, (parent.width - width) / 2)
                        spacing: 6
                        Repeater {
                            model: ConfigOptions.screenshot.palette
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
                                    onClicked: root.setColor(parent.modelData)
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
                                if (acceptableInput) root.setColor(text);
                                text = Qt.binding(() => root.strokeColor.toString());
                            }
                        }
                        StyledText {
                            visible: sizeControl.visible
                            text: qsTr("Size")
                        }
                        SpinBox {
                            id: sizeControl
                            visible: root.activeType !== "solid" && root.activeType !== "invert"
                            from: 1
                            to: 100
                            value: root.textMode ? root.textFormat.size : root.strokeWidth
                            editable: true
                            onValueModified: {
                                if (root.textMode) root.setTextFormat({ size: value });
                                else root.setWidth(value);
                            }
                        }
                        StyledText {
                            text: root.textMode ? qsTr("px · Ctrl+Enter to finish")
                                : root.tool === "counter" ? qsTr("Next number %1").arg(root.nextCounter)
                                : root.tool === "marker" ? qsTr("× 10 px · Shift to constrain")
                                : root.activeType === "conceal" || root.activeType === "pixelate"
                                    ? qsTr("× 4 px cells · Shift for a square")
                                : root.activeType === "blur" ? qsTr("× 2 px radius · Shift for a square")
                                : root.activeType === "solid" || root.activeType === "invert"
                                    ? qsTr("Shift for a square")
                                : qsTr("px · Shift to constrain")
                        }
                        ComboBox {
                            id: fontFamily
                            visible: root.textMode
                            Layout.preferredWidth: 200
                            focusPolicy: Qt.NoFocus
                            model: ["sans-serif", "serif", "monospace"].concat(Qt.fontFamilies())
                            currentIndex: Math.max(0, model.indexOf(root.textFormat.family))
                            onActivated: (index) => {
                                root.setTextFormat({ family: model[index] });
                                currentIndex = Qt.binding(() => Math.max(0, model.indexOf(root.textFormat.family)));
                                if (root.pendingText) textEditor.forceActiveFocus();
                            }
                        }
                        Repeater {
                            model: [
                                { key: "bold", icon: "format_bold", label: qsTr("Bold") },
                                { key: "italic", icon: "format_italic", label: qsTr("Italic") },
                                { key: "underline", icon: "format_underlined", label: qsTr("Underline") },
                                { key: "strikeout", icon: "format_strikethrough", label: qsTr("Strike-through") }
                            ]
                            delegate: AnnotatorToolButton {
                                required property var modelData
                                visible: root.textMode
                                implicitWidth: 36
                                implicitHeight: 36
                                icon: modelData.icon
                                label: modelData.label
                                active: root.textFormat[modelData.key]
                                onClicked: root.setTextFormat({ [modelData.key]: !root.textFormat[modelData.key] })
                            }
                        }
                        Repeater {
                            model: [
                                { align: "left", icon: "format_align_left", label: qsTr("Align left") },
                                { align: "center", icon: "format_align_center", label: qsTr("Align centre") },
                                { align: "right", icon: "format_align_right", label: qsTr("Align right") }
                            ]
                            delegate: AnnotatorToolButton {
                                required property var modelData
                                visible: root.textMode
                                implicitWidth: 36
                                implicitHeight: 36
                                icon: modelData.icon
                                label: modelData.label
                                active: root.textFormat.align === modelData.align
                                onClicked: root.setTextFormat({ align: modelData.align })
                            }
                        }
                    }
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    contentWidth: Math.max(width, exportActions.implicitWidth)
                    contentHeight: 48
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    ScrollBar.horizontal: ScrollBar {}

                    ScreenshotActions {
                        id: exportActions
                        objectName: "screenshotActions"
                        x: Math.max(0, (parent.width - width) / 2)
                        y: (48 - height) / 2
                        ready: root.renderReady
                        busy: output.busy
                        onRequested: (action, destination, options) => root.exportScreenshot(action, destination, options)
                        onInvalid: message => root.errorMessage = message
                    }
                }
            }
        }
    }

    function prepareClose(): void {
        PersistentStateManager.setState("screenshot.lastStyle", { tool: tool, color: strokeColor.toString(),
            width: strokeWidth, rounded: rounded, font: textFormat });
        cancelGesture();
        if (pendingText) cancelText();
        keyHandler.forceActiveFocus();
    }

    function cancelEditor(): void {
        prepareClose();
        root.cancelled();
    }

    function changeSize(delta): void {
        if (textMode) setTextFormat({ size: AnnotationTools.size(textFormat.size + delta) });
        else setWidth(AnnotationTools.size(strokeWidth + delta));
    }

    function applyObjects(nextShapes, nextCounterValue): void {
        editHistory = AnnotationEditing.commit(editHistory, nextShapes, nextCounterValue);
        selectedIndex = Math.min(selectedIndex, shapes.length - 1);
        canvas.requestPaint();
    }

    function activateTool(nextTool): void {
        cancelGesture();
        if (pendingText) commitText();
        tool = nextTool;
        selectedIndex = -1;
        keyHandler.forceActiveFocus();
    }

    function shapeDetail(shape) {
        if (shape.type === "arrow") return AnnotationTools.arrowGeometry(shape);
        if (shape.type === "counter") return AnnotationTools.counterGeometry(shape);
        return {};
    }

    function shapeBounds(shape) {
        return AnnotationEditing.bounds(shape, shapeDetail(shape));
    }

    function handlePoints(shape) {
        if (shape.type === "text") return [];
        if (["line", "arrow", "marker"].indexOf(shape.type) >= 0)
            return [{ x: shape.x1, y: shape.y1 }, { x: shape.x2, y: shape.y2 }];
        const points = AnnotationEditing.handles(AnnotationEditing.controlBounds(shape, shapeDetail(shape)));
        if (shape.type === "counter" && Math.hypot(shape.x2 - shape.x1, shape.y2 - shape.y1) > shape.radius)
            points.push({ x: shape.x2, y: shape.y2 });
        return points;
    }

    function hitObject(x, y): int {
        const tolerance = 5 / stage.scaleFactor;
        for (let i = shapes.length - 1; i >= 0; --i)
            if (AnnotationEditing.hit(shapes[i], x, y, tolerance, shapeDetail(shapes[i]))) return i;
        return -1;
    }

    function syncSelectedStyle(): void {
        if (!selectedShape) return;
        strokeColor = selectedShape.color;
        if (selectedShape.type === "text") textFormat = Object.assign({}, selectedShape.font);
        else strokeWidth = selectedShape.width / (selectedShape.type === "marker" ? 10 : 1);
        rounded = selectedShape.rounded ?? false;
    }

    function selectObject(index): void {
        if (pendingText && pendingTextIndex === index) return;
        if (pendingText) {
            const removed = commitText();
            if (removed >= 0 && removed < index) --index;
        }
        cancelGesture();
        selectedIndex = index >= 0 && index < shapes.length ? index : -1;
        tool = "select";
        syncSelectedStyle();
        keyHandler.forceActiveFocus();
    }

    function beginGesture(x, y, modifiers): void {
        x = ScreenshotPrecision.snap(x, ConfigOptions.screenshot.gridEnabled, ConfigOptions.screenshot.gridSpacing);
        y = ScreenshotPrecision.snap(y, ConfigOptions.screenshot.gridEnabled, ConfigOptions.screenshot.gridSpacing);
        // A click away from text completes it without also drawing another object.
        if (pendingText) {
            commitText();
            return;
        }
        keyHandler.forceActiveFocus();
        if (tool === "text") {
            gesture = { kind: "text", x: x, y: y };
            return;
        }
        if (tool !== "select") {
            gesture = { kind: "draw", preview: AnnotationTools.create(tool, x, y,
                strokeColor, strokeWidth, rounded, nextCounter) };
        } else {
            const corner = selectedShape && selectedShape.type !== "text"
                ? AnnotationEditing.handleAt(selectionHandles, x, y, 8 / stage.scaleFactor) : -1;
            const index = corner >= 0 ? selectedIndex : hitObject(x, y);
            selectObject(index);
            if (index < 0) return;
            const original = AnnotationEditing.copy(shapes[index]);
            const endpoint = corner >= 0 && (["line", "arrow", "marker"].indexOf(original.type) >= 0
                || (original.type === "counter" && corner === 4));
            const kind = endpoint ? "endpoint" : corner >= 0 ? "resize" : "move";
            gesture = { kind: kind, index: index, corner: corner,
                x: x, y: y, original: original, box: kind === "resize"
                    ? AnnotationEditing.controlBounds(original, shapeDetail(original)) : shapeBounds(original), preview: original };
        }
        canvas.requestPaint();
    }

    function updateGesture(x, y, modifiers): void {
        x = ScreenshotPrecision.snap(x, ConfigOptions.screenshot.gridEnabled, ConfigOptions.screenshot.gridSpacing);
        y = ScreenshotPrecision.snap(y, ConfigOptions.screenshot.gridEnabled, ConfigOptions.screenshot.gridSpacing);
        if (!gesture || gesture.kind === "text") return;
        if (gesture.kind === "draw") {
            AnnotationTools.update(gesture.preview, x, y, !!(modifiers & Qt.ShiftModifier), stage.width, stage.height);
        } else {
            const dx = x - gesture.x, dy = y - gesture.y;
            let shape = gesture.original;
            if (Math.hypot(dx, dy) * stage.scaleFactor >= 2) {
                if (gesture.kind === "move") {
                    shape = AnnotationEditing.move(shape, dx, dy, gesture.box, stage.width, stage.height);
                } else if (gesture.kind === "endpoint") {
                    shape = AnnotationEditing.copy(shape);
                    const first = gesture.corner === 0 && shape.type !== "counter";
                    const xKey = first ? "x1" : "x2", yKey = first ? "y1" : "y2";
                    shape[xKey] = AnnotationTools.clamp(shape[xKey] + dx, 0, stage.width);
                    shape[yKey] = AnnotationTools.clamp(shape[yKey] + dy, 0, stage.height);
                } else {
                    const handle = AnnotationEditing.handles(gesture.box)[gesture.corner];
                    let box = AnnotationEditing.resizedBox(gesture.box, gesture.corner,
                        handle.x + dx, handle.y + dy, stage.width, stage.height, shape.type === "counter");
                    if (shape.type === "counter") {
                        const factor = AnnotationTools.clamp(box.width / gesture.box.width,
                            12.5 / shape.radius, 260 / shape.radius);
                        box = AnnotationEditing.scaledBox(gesture.box, gesture.corner, factor);
                        shape = AnnotationEditing.resize(shape, gesture.box, box);
                        shape.radius = gesture.original.radius * factor;
                        shape.width = (shape.radius - 10) / 2.5;
                    } else {
                        shape = AnnotationEditing.resize(shape, gesture.box, box);
                    }
                }
            }
            gesture = Object.assign({}, gesture, { preview: shape });
        }
        canvas.requestPaint();
    }

    function finishGesture(x, y, modifiers): void {
        x = ScreenshotPrecision.snap(x, ConfigOptions.screenshot.gridEnabled, ConfigOptions.screenshot.gridSpacing);
        y = ScreenshotPrecision.snap(y, ConfigOptions.screenshot.gridEnabled, ConfigOptions.screenshot.gridSpacing);
        if (!gesture) return;
        if (gesture.kind === "text") {
            gesture = null;
            startText(x, y);
            return;
        }
        updateGesture(x, y, modifiers);
        const completed = gesture;
        gesture = null;
        if (completed.kind === "draw") {
            const shape = completed.preview;
            if (shape.type !== "pen" && shape.type !== "counter"
                && (((["rect", "fill", "ellipse"].indexOf(shape.type) >= 0 || AnnotationTools.isEffect(shape.type))
                    && (shape.x1 === shape.x2 || shape.y1 === shape.y2))
                    || (shape.x1 === shape.x2 && shape.y1 === shape.y2))) {
                canvas.requestPaint();
                return;
            }
            applyObjects(shapes.concat([completed.preview]),
                nextCounter + (completed.preview.type === "counter" ? 1 : 0));
        } else {
            const next = shapes.slice();
            next[completed.index] = completed.preview;
            applyObjects(next, nextCounter);
            syncSelectedStyle();
        }
        canvas.requestPaint();
    }

    function cancelGesture(): void {
        gesture = null;
        canvas.requestPaint();
    }

    function styleSelection(patch): void {
        if (!selectedShape || pendingText) return;
        const shape = Object.assign(AnnotationEditing.copy(selectedShape), patch);
        if (shape.type === "text") layoutText(shape);
        const next = shapes.slice();
        next[selectedIndex] = shape;
        applyObjects(next, nextCounter);
    }

    function setColor(value): void {
        strokeColor = value;
        if (selectedShape && !AnnotationTools.usesColor(selectedShape.type)) return;
        const patch = { color: strokeColor.toString() };
        if (selectedShape?.type === "counter") patch.textColor = AnnotationTools.contrastColor(strokeColor);
        styleSelection(patch);
    }

    function setWidth(value): void {
        if (activeType === "solid" || activeType === "invert") return;
        strokeWidth = AnnotationTools.size(value);
        const patch = { width: strokeWidth * (selectedShape?.type === "marker" ? 10 : 1) };
        if (selectedShape?.type === "counter") patch.radius = AnnotationTools.counterRadius(strokeWidth);
        styleSelection(patch);
    }

    function setRounded(value): void {
        rounded = value;
        if (selectedShape?.type === "rect" || selectedShape?.type === "fill") styleSelection({ rounded: value });
    }

    function editSelectedText(): void {
        if (selectedShape?.type !== "text" || pendingText) return;
        cancelGesture();
        startText(selectedShape.x1, selectedShape.y1, selectedShape, selectedIndex);
    }

    function deleteSelection(): void {
        if (!selectedShape) return;
        cancelGesture();
        if (pendingText) cancelText();
        const next = shapes.slice();
        next.splice(selectedIndex, 1);
        selectedIndex = -1;
        applyObjects(next, nextCounter);
        keyHandler.forceActiveFocus();
    }

    function reorderSelection(direction): void {
        if (pendingText) commitText();
        const destination = selectedIndex + direction;
        if (!selectedShape || destination < 0 || destination >= shapes.length) return;
        const next = shapes.slice();
        const shape = next.splice(selectedIndex, 1)[0];
        next.splice(destination, 0, shape);
        applyObjects(next, nextCounter);
        selectedIndex = destination;
        keyHandler.forceActiveFocus();
    }

    function restoreHistory(next): void {
        cancelGesture();
        if (pendingText) cancelText();
        editHistory = next;
        selectedIndex = Math.min(selectedIndex, shapes.length - 1);
        syncSelectedStyle();
        canvas.requestPaint();
        keyHandler.forceActiveFocus();
    }

    function undoEdit(): void {
        if (gesture) { cancelGesture(); return; }
        if (pendingText) { cancelText(); return; }
        restoreHistory(AnnotationEditing.undo(editHistory));
    }
    function redoEdit(): void {
        if (gesture) { cancelGesture(); return; }
        if (pendingText) { cancelText(); return; }
        restoreHistory(AnnotationEditing.redo(editHistory));
    }

    function setTextFormat(patch): void {
        textFormat = Object.assign({}, textFormat, patch);
        if (selectedShape?.type === "text" && !pendingText)
            styleSelection({ font: Object.assign({}, selectedShape.font, patch) });
    }
    onRenderSourceChanged: {
        renderLoaded = false;
        canvas.loadImage(renderSource);
    }
    onTextFormatChanged: refreshPendingText()
    onStrokeColorChanged: refreshPendingText()

    // Stores the line metrics the renderer uses, giving text a source-coordinate box.
    function layoutText(shape) {
        const font = shape.font;
        fontProbe.font = Qt.font({ family: font.family, pixelSize: font.size,
            bold: font.bold, italic: font.italic });
        const lines = shape.text.split("\n");
        const widths = lines.map(line => fontProbe.advanceWidth(line));
        // TextEdit advances whole pixels per line, so the transparent caret tracks the canvas.
        const lineHeight = Math.ceil(fontProbe.height);
        shape.layout = { lineHeight: lineHeight, ascent: fontProbe.ascent,
            underline: fontProbe.underlinePosition, strike: fontProbe.strikeOutPosition,
            thickness: Math.max(1, fontProbe.lineWidth), widths: widths };
        shape.x2 = shape.x1 + Math.max(...widths);
        shape.y2 = shape.y1 + lines.length * lineHeight;
        return shape;
    }

    function textObject(x, y, text) {
        return layoutText({ type: "text", x1: x, y1: y, text: text, opacity: 1,
            color: strokeColor.toString(), font: Object.assign({}, textFormat) });
    }

    // Pass a committed text object and its index to reopen it in place.
    function startText(x, y, existing, index): void {
        if (pendingText) commitText();
        if (existing) {
            textFormat = Object.assign({}, existing.font);
            strokeColor = existing.color;
        }
        pendingTextIndex = existing ? index : -1;
        pendingText = existing ? textObject(existing.x1, existing.y1, existing.text) : textObject(x, y, "");
        textEditor.text = pendingText.text;
        textEditor.cursorPosition = textEditor.length;
        textEditor.forceActiveFocus();
        canvas.requestPaint();
    }

    function refreshPendingText(): void {
        if (!pendingText) return;
        pendingText = textObject(pendingText.x1, pendingText.y1, textEditor.text);
        canvas.requestPaint();
    }

    function closeText(): void {
        pendingText = null;
        pendingTextIndex = -1;
        textEditor.text = "";
        keyHandler.forceActiveFocus();
        canvas.requestPaint();
    }

    function commitText(): int {
        const pending = pendingText;
        const index = pendingTextIndex;
        closeText();
        if (!pending) return -1;
        const empty = pending.text.trim().length === 0;
        const next = shapes.slice();
        if (index < 0) {
            if (empty) return -1;
            next.push(pending);
        } else if (empty) {
            next.splice(index, 1);
            if (selectedIndex === index) selectedIndex = -1;
            else if (selectedIndex > index) --selectedIndex;
        } else {
            if (JSON.stringify(shapes[index]) === JSON.stringify(pending)) return -1;
            next[index] = pending;
        }
        applyObjects(next, nextCounter);
        return index >= 0 && empty ? index : -1;
    }

    function cancelText(): void {
        closeText();
    }

    FontMetrics {
        id: fontProbe
    }

    required property string renderedPath
    property string errorMessage: ""
    property string pendingPin: ""
    readonly property bool exporting: output.busy
    onClosed: root.cancelEditor()
    Component.onDestruction: if (pendingPin.length > 0) ScreenPins.release(pendingPin)

    // flattened source and committed objects at source resolution
    function renderImage(path): bool {
        if (!renderReady)
            return false
        if (pendingText)
            commitText()
        cancelGesture()
        canvas.renderShapes() // no wait for the next frame
        return canvas.save(path)
    }

    function cancelOutput(): void {
        output.cancel();
    }

    function exportScreenshot(action, destination, options): void {
        if (output.busy || (action !== "copy-path" && !renderReady)) return;
        errorMessage = "";
        if (action !== "copy-path" && !renderImage(renderedPath)) {
            errorMessage = qsTr("Could not render the screenshot. Please try again.");
            root.saveFailed();
            return;
        }
        if (action === "pin") {
            pendingPin = ScreenPins.reserve();
            destination = pendingPin;
        }
        output.perform(renderedPath, action, destination, options);
    }

    ScreenshotOutput {
        id: output
        originalPath: root.localImagePath
        onFinished: (path, copied) => {
            if (output.action === "pin") {
                ScreenPins.show(root.pendingPin, root.localImagePath);
                root.pendingPin = "";
                return;
            }
            if (output.action === "save" || output.action === "save-copy") exportActions.savedPath = path;
            if (output.action !== "save" && output.action !== "copy-path") root.saved(path, copied);
        }
        onFailed: message => {
            if (output.action === "pin") {
                ScreenPins.release(root.pendingPin);
                root.pendingPin = "";
            } else if (output.outputPath.length > 0) exportActions.savedPath = output.outputPath;
            root.saveFailed();
            root.errorMessage = message;
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
        color: btn.active ? Appearance.m3colors.m3primaryContainer
            : (mouse.containsMouse ? "#33ffffff" : "#22ffffff")
        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 24
            text: btn.icon
            fill: btn.filledIcon ? 1 : 0
            color: btn.active ? Appearance.m3colors.m3onPrimaryContainer : root.uiForeground
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
