// Simple screenshot annotator

pragma ComponentBehavior: "Bound"
import "./Modules/Common/"
import "./Modules/Common/Widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "./Services/"

ShellRoot {
    id: root

    property string imagePath: (Quickshell.env("ANNOTATE_IMG") ?? "").replace(/^file:\/\//, "")
    property color strokeColor: "#ff3b30"
    property real strokeWidth: 3
    property string tool: "arrow"
    property var shapes: []

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme();
        ConfigLoader.loadConfig();
        if (root.imagePath.length === 0) {
            console.warn("[annotator] No ANNOTATE_IMG provided, nothing to edit.");
            Qt.quit();
        }
    }

    function outputPath() {
        const p = root.imagePath;
        const slash = p.lastIndexOf('/');
        const dot = p.lastIndexOf('.');
        if (dot > slash) return p.substring(0, dot) + "_annotated" + p.substring(dot);
        return p + "_annotated.png";
    }

    FloatingWindow {
        id: win
        title: "Annotate screenshot"
        color: "#1a1a1a"
        visible: true

        readonly property real toolbarH: 72
        readonly property var scr: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
            ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        readonly property real maxW: (scr?.width ?? 1920) * 0.9
        readonly property real maxH: (scr?.height ?? 1080) * 0.9

        implicitWidth: {
            if (sourceImage.status !== Image.Ready || sourceImage.implicitWidth <= 0) return 900;
            const fit = Math.min(maxW / sourceImage.implicitWidth,
                                 (maxH - toolbarH) / sourceImage.implicitHeight, 1);
            return Math.round(sourceImage.implicitWidth * fit) + 32;
        }
        implicitHeight: {
            if (sourceImage.status !== Image.Ready || sourceImage.implicitHeight <= 0) return 640;
            const fit = Math.min(maxW / sourceImage.implicitWidth,
                                 (maxH - toolbarH) / sourceImage.implicitHeight, 1);
            return Math.round(sourceImage.implicitHeight * fit) + 32 + toolbarH;
        }
        minimumSize: Qt.size(360, 280)

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    if (textEditor.visible) {
                        win.cancelText();
                        event.accepted = true;
                    } else {
                        Qt.quit();
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
                            || sourceImage.implicitWidth <= 0) return 1;
                        return Math.min((stageArea.width - 24) / sourceImage.implicitWidth,
                                        (stageArea.height - 24) / sourceImage.implicitHeight, 1);
                    }
                    width: sourceImage.implicitWidth * scaleFactor
                    height: sourceImage.implicitHeight * scaleFactor

                    Image {
                        id: sourceImage
                        anchors.fill: parent
                        source: "file://" + root.imagePath
                        fillMode: Image.Stretch
                        smooth: true
                        cache: false
                    }

                    Canvas {
                        id: canvas
                        anchors.fill: parent

                        function drawArrow(ctx, x1, y1, x2, y2) {
                            const head = 16;
                            const ang = Math.atan2(y2 - y1, x2 - x1);
                            ctx.beginPath();
                            ctx.moveTo(x1, y1);
                            ctx.lineTo(x2, y2);
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.moveTo(x2, y2);
                            ctx.lineTo(x2 - head * Math.cos(ang - Math.PI / 6),
                                       y2 - head * Math.sin(ang - Math.PI / 6));
                            ctx.moveTo(x2, y2);
                            ctx.lineTo(x2 - head * Math.cos(ang + Math.PI / 6),
                                       y2 - head * Math.sin(ang + Math.PI / 6));
                            ctx.stroke();
                        }

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.strokeStyle = root.strokeColor;
                            ctx.fillStyle = root.strokeColor;
                            ctx.lineWidth = root.strokeWidth;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            ctx.font = "bold 22px sans-serif";
                            ctx.textBaseline = "top";

                            const all = drawArea.preview
                                ? root.shapes.concat([drawArea.preview])
                                : root.shapes;
                            for (const s of all) {
                                if (s.type === "rect") {
                                    ctx.strokeRect(Math.min(s.x1, s.x2), Math.min(s.y1, s.y2),
                                                   Math.abs(s.x2 - s.x1), Math.abs(s.y2 - s.y1));
                                } else if (s.type === "arrow") {
                                    drawArrow(ctx, s.x1, s.y1, s.x2, s.y2);
                                } else if (s.type === "text") {
                                    ctx.fillText(s.text, s.x1, s.y1);
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: drawArea
                        anchors.fill: parent
                        cursorShape: Qt.CrossCursor
                        acceptedButtons: Qt.LeftButton

                        property var start: null
                        property var preview: null

                        onPressed: (mouse) => {
                            if (textEditor.visible) { win.commitText(); return; }
                            if (root.tool === "text") return;
                            start = { x: mouse.x, y: mouse.y };
                        }
                        onPositionChanged: (mouse) => {
                            if (!start) return;
                            preview = { type: root.tool, x1: start.x, y1: start.y,
                                        x2: mouse.x, y2: mouse.y };
                            canvas.requestPaint();
                        }
                        onReleased: (mouse) => {
                            if (root.tool === "text") { win.startText(mouse.x, mouse.y); return; }
                            if (!start) return;
                            if (Math.hypot(mouse.x - start.x, mouse.y - start.y) > 3) {
                                root.shapes = root.shapes.concat([{
                                    type: root.tool, x1: start.x, y1: start.y,
                                    x2: mouse.x, y2: mouse.y
                                }]);
                            }
                            start = null;
                            preview = null;
                            canvas.requestPaint();
                        }
                    }

                    // Inline text entry, positioned where the user clicked
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
                        onAccepted: win.commitText()
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) { win.cancelText(); event.accepted = true; }
                        }
                    }
                }
            }

            // --- Toolbar ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: win.toolbarH
                color: "#22ffffff"

                RowLayout {
                    id: toolRow
                    anchors.centerIn: parent
                    spacing: 8

                    AnnotatorToolButton {
                        icon: "north_east"
                        active: root.tool === "arrow"
                        onClicked: root.tool = "arrow"
                    }
                    AnnotatorToolButton {
                        icon: "crop_square"
                        active: root.tool === "rect"
                        onClicked: root.tool = "rect"
                    }
                    AnnotatorToolButton {
                        icon: "title"
                        active: root.tool === "text"
                        onClicked: root.tool = "text"
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 32
                        color: "#33ffffff"
                    }

                    AnnotatorToolButton {
                        icon: "content_copy"
                        onClicked: win.saveAndCopy()
                    }
                    AnnotatorToolButton {
                        icon: "close"
                        onClicked: Qt.quit()
                    }
                }
            }
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
                    text: textEditor.text
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

        property int grabRetries: 0
        function saveAndCopy() {
            if (textEditor.visible) commitText();
            const grab = stage.grabToImage((result) => {
                win.grabRetries = 0;
                const out = root.outputPath();
                result.saveToFile(out);
                // agents paste into a terminal, where a path beats image bytes
                Quickshell.execDetached(["wl-copy", "--type", "text/plain", out]);
                Quickshell.execDetached(["notify-send", "Screenshot saved",
                    `Image saved in <i>${out}</i> and copied to the clipboard.`,
                    "-t", "5000", "-i", out, "-a", "Hyprshot"]);
                quitTimer.start();
            });
            if (!grab) {
                if (win.grabRetries++ < 30) retryTimer.start();
                else console.warn("[annotator] grabToImage failed; nothing copied");
            }
        }

        Timer { id: retryTimer; interval: 100; onTriggered: win.saveAndCopy() }
        Timer { id: quitTimer; interval: 400; onTriggered: Qt.quit() }

        component AnnotatorToolButton: Rectangle {
            id: btn
            property string icon: ""
            property bool active: false
            signal clicked()
            implicitWidth: 48
            implicitHeight: 48
            radius: Appearance?.rounding?.small ?? 8
            color: btn.active ? root.strokeColor
                : (mouse.containsMouse ? "#33ffffff" : "#22ffffff")
            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: 24
                text: btn.icon
                color: btn.active ? "#ffffff" : "#eeeeee"
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: btn.clicked()
            }
        }
    }
}
