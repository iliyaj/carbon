import qs.Modules.Common
import qs.Modules.Common.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:screenCapture"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    signal accepted(string geometry)
    signal cancelled()

    property string acceptText: qsTr("Capture screenshot")
    property url backgroundSource
    property alias ratioIndex: ratioPicker.currentIndex
    property size initialSize: Qt.size(1080, 1350)
    property int dimensionStep: 1
    property int regionX: 0
    property int regionY: 0
    property int regionWidth: dimensionStep
    property int regionHeight: dimensionStep
    property bool drawing: false
    readonly property int maxWidth: Math.floor(screen.width / dimensionStep) * dimensionStep
    readonly property int maxHeight: Math.floor(screen.height / dimensionStep) * dimensionStep
    readonly property var ratios: [0, 4 / 5, 1, 9 / 16, 16 / 9, 4 / 3, 3 / 2]
    readonly property real ratio: ratioPicker.currentIndex < ratios.length
        ? ratios[ratioPicker.currentIndex] : customRatioValue
    onRatioChanged: applyRatio()
    readonly property real customRatioValue: {
        const parts = customRatio.text.trim().split(":")
        return /^[1-9]\d{0,4}\s*:\s*[1-9]\d{0,4}$/.test(customRatio.text.trim())
            ? Number(parts[0]) / Number(parts[1]) : 0
    }
    readonly property bool validInputs: widthInput.acceptableInput && heightInput.acceptableInput
        && Number(widthInput.text) % dimensionStep === 0 && Number(heightInput.text) % dimensionStep === 0
        && (ratioPicker.currentIndex !== ratios.length || customRatioValue > 0)

    function aligned(value: real): int {
        return Math.max(dimensionStep, Math.floor(value / dimensionStep) * dimensionStep)
    }

    function moveTo(x: real, y: real): void {
        regionX = Math.round(Math.max(0, Math.min(x, screen.width - regionWidth)))
        regionY = Math.round(Math.max(0, Math.min(y, screen.height - regionHeight)))
    }

    function fitSize(w: real, h: real): void {
        const factor = Math.min(1, maxWidth / w, maxHeight / h)
        regionWidth = aligned(w * factor)
        regionHeight = aligned(h * factor)
        moveTo(regionX, regionY)
    }

    function editSize(value: string, horizontal: bool): void {
        const number = Number(value)
        const maximum = horizontal ? maxWidth : maxHeight
        if (!/^[1-9]\d*$/.test(value) || number > maximum || number % dimensionStep !== 0)
            return
        // Typing dimensions is exact; ratio presets constrain mouse resizing only.
        ratioPicker.currentIndex = 0
        fitSize(horizontal ? number : regionWidth, horizontal ? regionHeight : number)
    }

    function applyRatio(): void {
        if (ratio <= 0)
            return
        fitSize(regionWidth, regionWidth / ratio)
    }

    function confirm(): void {
        if (!validInputs || drawing)
            return
        root.accepted(`${screen.x + regionX},${screen.y + regionY} ${regionWidth}x${regionHeight}`)
    }

    Component.onCompleted: {
        fitSize(initialSize.width, initialSize.height)
        moveTo((screen.width - regionWidth) / 2, (screen.height - regionHeight) / 2)
        canvas.forceActiveFocus()
    }

    Item {
        id: canvas
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.cancelled()

        Image {
            anchors.fill: parent
            source: root.backgroundSource
            cache: false
        }

        // Four rectangles dim the desktop without tinting the selected pixels.
        Rectangle { width: parent.width; height: root.regionY; color: "#88000000" }
        Rectangle {
            y: root.regionY + root.regionHeight
            width: parent.width; height: parent.height - y
            color: "#88000000"
        }
        Rectangle {
            y: root.regionY; width: root.regionX; height: root.regionHeight
            color: "#88000000"
        }
        Rectangle {
            x: root.regionX + root.regionWidth; y: root.regionY
            width: parent.width - x; height: root.regionHeight
            color: "#88000000"
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            property real startX: 0
            property real startY: 0
            onPressed: mouse => {
                canvas.forceActiveFocus()
                startX = mouse.x
                startY = mouse.y
                root.drawing = true
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return
                const endX = Math.max(0, Math.min(mouse.x, width))
                const endY = Math.max(0, Math.min(mouse.y, height))
                let w = Math.max(root.dimensionStep, Math.abs(endX - startX))
                let h = Math.max(root.dimensionStep, Math.abs(endY - startY))
                if (root.ratio > 0) {
                    w = Math.min(w, h * root.ratio)
                    h = w / root.ratio
                    const availableW = endX >= startX ? width - startX : startX
                    const availableH = endY >= startY ? height - startY : startY
                    const factor = Math.min(1, availableW / w, availableH / h)
                    w *= factor
                    h *= factor
                }
                root.fitSize(w, h)
                root.moveTo(endX >= startX ? startX : startX - root.regionWidth,
                    endY >= startY ? startY : startY - root.regionHeight)
            }
            onReleased: root.drawing = false
            onCanceled: root.drawing = false
        }

        Rectangle {
            id: selection
            x: root.regionX; y: root.regionY
            width: root.regionWidth; height: root.regionHeight
            color: "transparent"
            border.width: 2
            border.color: Appearance.colors.colPrimary

            MouseArea {
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point start
                property point origin
                onPressed: mouse => {
                    canvas.forceActiveFocus()
                    start = mapToItem(canvas, mouse.x, mouse.y)
                    origin = Qt.point(root.regionX, root.regionY)
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return
                    const position = mapToItem(canvas, mouse.x, mouse.y)
                    root.moveTo(origin.x + position.x - start.x, origin.y + position.y - start.y)
                }
            }

            Repeater {
                model: [
                    { hx: 0, hy: 0 }, { hx: 0.5, hy: 0 }, { hx: 1, hy: 0 },
                    { hx: 0, hy: 0.5 }, { hx: 1, hy: 0.5 },
                    { hx: 0, hy: 1 }, { hx: 0.5, hy: 1 }, { hx: 1, hy: 1 }
                ]
                delegate: Rectangle {
                    id: handle
                    required property var modelData
                    x: modelData.hx * selection.width - width / 2
                    y: modelData.hy * selection.height - height / 2
                    width: 12; height: 12; radius: 2
                    color: Appearance.colors.colPrimary
                    border.width: 1; border.color: "white"

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: handle.modelData.hx === 0.5 ? Qt.SizeVerCursor
                            : handle.modelData.hy === 0.5 ? Qt.SizeHorCursor
                            : handle.modelData.hx === handle.modelData.hy ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                        property point start
                        property rect original
                        onPressed: mouse => {
                            canvas.forceActiveFocus()
                            start = mapToItem(canvas, mouse.x, mouse.y)
                            original = Qt.rect(root.regionX, root.regionY, root.regionWidth, root.regionHeight)
                        }
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return
                            const position = mapToItem(canvas, mouse.x, mouse.y)
                            const dx = position.x - start.x
                            const dy = position.y - start.y
                            const hx = handle.modelData.hx
                            const hy = handle.modelData.hy
                            let left = original.x
                            let top = original.y
                            let right = original.x + original.width
                            let bottom = original.y + original.height
                            if (hx === 0) left = Math.max(0, Math.min(left + dx, right - root.dimensionStep))
                            if (hx === 1) right = Math.min(root.width, Math.max(right + dx, left + root.dimensionStep))
                            if (hy === 0) top = Math.max(0, Math.min(top + dy, bottom - root.dimensionStep))
                            if (hy === 1) bottom = Math.min(root.height, Math.max(bottom + dy, top + root.dimensionStep))
                            let w = right - left
                            let h = bottom - top
                            if (root.ratio > 0) {
                                if (hx === 0.5) w = h * root.ratio
                                else h = w / root.ratio
                                const limitW = hx === 0 ? original.x + original.width : root.width - original.x
                                const limitH = hy === 0 ? original.y + original.height : root.height - original.y
                                const factor = Math.min(1, limitW / w, limitH / h)
                                w *= factor
                                h *= factor
                            }
                            root.fitSize(w, h)
                            root.moveTo(hx === 0 ? original.x + original.width - root.regionWidth : original.x,
                                hy === 0 ? original.y + original.height - root.regionHeight : original.y)
                        }
                    }
                }
            }
        }

        Rectangle {
            id: toolbar
            readonly property real gap: 12
            width: Math.min(460, canvas.width - 16)
            height: controls.implicitHeight + 24
            x: root.regionX + root.regionWidth + gap + width <= canvas.width
                ? root.regionX + root.regionWidth + gap
                : root.regionX >= width + gap ? root.regionX - width - gap
                : Math.max(8, Math.min(root.regionX, canvas.width - width - 8))
            y: root.regionY >= height + gap ? root.regionY - height - gap
                : root.regionY + root.regionHeight + gap + height <= canvas.height
                    ? root.regionY + root.regionHeight + gap
                    : Math.max(8, Math.min(root.regionY, canvas.height - height - 8))
            visible: !root.drawing
            radius: Appearance.rounding.normal
            color: Appearance.colors.colSurfaceContainerHigh
            border.width: 1
            border.color: Appearance.colors.colPrimary

            // Consume clicks in the gaps so they cannot start a new selection.
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                id: controls
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    TextField {
                        id: widthInput
                        Layout.preferredWidth: 80
                        text: String(root.regionWidth)
                        validator: IntValidator { bottom: root.dimensionStep; top: root.maxWidth }
                        color: Appearance.m3colors.m3onSurface
                        font.pixelSize: Appearance.font.pixelSize.normal
                        selectByMouse: true
                        KeyNavigation.tab: heightInput
                        KeyNavigation.backtab: heightInput
                        onTextEdited: root.editSize(text, true)
                        onAccepted: canvas.forceActiveFocus()
                        background: Rectangle { radius: 4; color: Appearance.colors.colSurfaceContainer }
                    }
                    StyledText { text: "×" }
                    TextField {
                        id: heightInput
                        Layout.preferredWidth: 80
                        text: String(root.regionHeight)
                        validator: IntValidator { bottom: root.dimensionStep; top: root.maxHeight }
                        color: Appearance.m3colors.m3onSurface
                        font.pixelSize: Appearance.font.pixelSize.normal
                        selectByMouse: true
                        KeyNavigation.tab: widthInput
                        KeyNavigation.backtab: widthInput
                        onTextEdited: root.editSize(text, false)
                        onAccepted: canvas.forceActiveFocus()
                        background: Rectangle { radius: 4; color: Appearance.colors.colSurfaceContainer }
                    }
                    ComboBox {
                        id: ratioPicker
                        Layout.fillWidth: true
                        model: [qsTr("Free"), "4:5", "1:1", "9:16", "16:9", "4:3", "3:2", qsTr("Custom ratio")]
                        currentIndex: 1
                    }
                }
                TextField {
                    id: customRatio
                    visible: ratioPicker.currentIndex === root.ratios.length
                    Layout.fillWidth: true
                    placeholderText: qsTr("Width:height, e.g. 4:5")
                    color: Appearance.m3colors.m3onSurface
                    selectByMouse: true
                    background: Rectangle { radius: 4; color: Appearance.colors.colSurfaceContainer }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.validInputs ? qsTr("Drag the box to move it. Drag outside to select again.")
                        : root.dimensionStep === 2 ? qsTr("Enter even dimensions that fit on this screen.")
                        : qsTr("Enter pixel dimensions that fit on this screen.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Appearance.font.pixelSize.small
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    DialogButton { buttonText: qsTr("Cancel"); onClicked: root.cancelled() }
                    DialogButton {
                        buttonText: root.acceptText
                        enabled: root.validInputs
                        onClicked: root.confirm()
                    }
                }
            }
        }
    }
}
