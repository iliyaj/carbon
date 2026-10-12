import qs.Modules.Common
import qs.Modules.Common.Widgets
import "screenshot_preferences.js" as ScreenshotPreferences
import "screenshot_precision.js" as ScreenshotPrecision
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
    property size selectionSize: Qt.size(screen.width, screen.height)
    property rect initialRegion: Qt.rect(0, 0, 0, 0)
    property bool acceptOnSelection: false
    property bool screenshotMode: false
    property bool magnifier: screenshotMode && ConfigOptions.screenshot.magnifier
    onMagnifierChanged: {
        if (magnifier && pixelCanvas.available && backgroundSource.toString())
            pixelCanvas.loadImage(backgroundSource.toString())
    }
    property var inspectedPixel: null
    property point pointerPosition: Qt.point(0, 0)
    property point sourcePointer: Qt.point(0, 0)
    readonly property bool snapEnabled: screenshotMode && ConfigOptions.screenshot.gridEnabled
    readonly property int gridSpacing: ConfigOptions.screenshot.gridSpacing
    readonly property color dimColor: Qt.rgba(0, 0, 0, screenshotMode ? ConfigOptions.screenshot.overlayOpacity : 0.5333333333)
    readonly property real previewScale: Math.min(width / selectionSize.width, height / selectionSize.height)
    property int dimensionStep: 1
    property int regionX: 0
    property int regionY: 0
    property int regionWidth: dimensionStep
    property int regionHeight: dimensionStep
    property bool drawing: false
    readonly property int maxWidth: Math.floor(selectionSize.width / dimensionStep) * dimensionStep
    readonly property int maxHeight: Math.floor(selectionSize.height / dimensionStep) * dimensionStep
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

    function moveTo(x: real, y: real, snap = false): void {
        x = ScreenshotPrecision.snap(x, snap && snapEnabled, gridSpacing)
        y = ScreenshotPrecision.snap(y, snap && snapEnabled, gridSpacing)
        regionX = Math.round(Math.max(0, Math.min(x, selectionSize.width - regionWidth)))
        regionY = Math.round(Math.max(0, Math.min(y, selectionSize.height - regionHeight)))
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

    function selectAll(): void {
        ratioPicker.currentIndex = 0
        fitSize(maxWidth, maxHeight)
        moveTo(0, 0)
    }

    function keyboard(action): void {
        const next = ScreenshotPrecision.keyboardRegion({ x: regionX, y: regionY, width: regionWidth, height: regionHeight },
            action, selectionSize.width, selectionSize.height, dimensionStep)
        ratioPicker.currentIndex = 0
        regionWidth = next.width; regionHeight = next.height
        // Keyboard movement is exact even when mouse grid snapping is enabled.
        regionX = next.x; regionY = next.y
    }

    function inspectPixel(x, y): void {
        sourcePointer = Qt.point(x, y)
        pointerPosition = imageCanvas.mapToItem(canvas, x, y)
        if (!pixelCanvas.isImageLoaded(backgroundSource.toString())) return
        inspectedPixel = ScreenshotPrecision.pixels(pixelCanvas.getContext("2d"), x, y, selectionSize.width, selectionSize.height)
    }

    Component.onCompleted: {
        if (initialRegion.width > 0 && initialRegion.height > 0) {
            fitSize(initialRegion.width, initialRegion.height)
            moveTo(initialRegion.x, initialRegion.y)
        } else {
            fitSize(initialSize.width, initialSize.height)
            moveTo((selectionSize.width - regionWidth) / 2, (selectionSize.height - regionHeight) / 2)
        }
        canvas.forceActiveFocus()
    }

    Item {
        id: canvas
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (widthInput.activeFocus || heightInput.activeFocus || customRatio.activeFocus) return
            const action = ScreenshotPreferences.action(event, root.screenshotMode ? ConfigOptions.screenshot.shortcuts : {}, Qt)
            if (action === "cancel") root.cancelled()
            else if (action === "editText" || action === "commitText") root.confirm()
            else if (action === "all") root.selectAll()
            else if (action === "magnifier") root.magnifier = !root.magnifier
            else if (/^(left|right|up|down|resize|symmetric)/.test(action)) root.keyboard(action)
            else return
            event.accepted = true
        }

        Item {
            id: imageCanvas
            anchors.centerIn: parent
            width: root.selectionSize.width
            height: root.selectionSize.height
            scale: root.previewScale

            Image {
                anchors.fill: parent
                source: root.backgroundSource
                cache: false
            }

            Canvas {
                id: pixelCanvas
                // Qt's queued contextType setup can outlive a cancelled selector's QML context.
                visible: false
                width: root.selectionSize.width / root.devicePixelRatio
                height: root.selectionSize.height / root.devicePixelRatio
                onAvailableChanged: { if (available && root.magnifier && root.backgroundSource.toString()) loadImage(root.backgroundSource.toString()) }
                onImageLoaded: {
                    const ctx = getContext("2d")
                    ctx.reset(); ctx.scale(1 / root.devicePixelRatio, 1 / root.devicePixelRatio)
                    ctx.drawImage(root.backgroundSource.toString(), 0, 0, root.selectionSize.width, root.selectionSize.height)
                    if (root.magnifier) root.inspectPixel(root.sourcePointer.x, root.sourcePointer.y)
                }
            }

            // Four rectangles dim the desktop without tinting the selected pixels.
            Rectangle { width: parent.width; height: root.regionY; color: root.dimColor }
            Rectangle {
                y: root.regionY + root.regionHeight
                width: parent.width; height: parent.height - y
                color: root.dimColor
            }
            Rectangle {
                y: root.regionY; width: root.regionX; height: root.regionHeight
                color: root.dimColor
            }
            Rectangle {
                x: root.regionX + root.regionWidth; y: root.regionY
                width: parent.width - x; height: root.regionHeight
                color: root.dimColor
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                hoverEnabled: true
                property real startX: 0
                property real startY: 0
                onPressed: mouse => {
                    canvas.forceActiveFocus()
                    startX = ScreenshotPrecision.snap(mouse.x, root.snapEnabled, root.gridSpacing)
                    startY = ScreenshotPrecision.snap(mouse.y, root.snapEnabled, root.gridSpacing)
                    root.drawing = true
                }
                onPositionChanged: mouse => {
                    if (root.magnifier) root.inspectPixel(mouse.x, mouse.y)
                    if (!pressed)
                        return
                    const endX = Math.max(0, Math.min(ScreenshotPrecision.snap(mouse.x, root.snapEnabled, root.gridSpacing), width))
                    const endY = Math.max(0, Math.min(ScreenshotPrecision.snap(mouse.y, root.snapEnabled, root.gridSpacing), height))
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
                onReleased: mouse => {
                    root.drawing = false
                    if (root.acceptOnSelection && Math.abs(mouse.x - startX) >= root.dimensionStep
                        && Math.abs(mouse.y - startY) >= root.dimensionStep)
                        root.confirm()
                }
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
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property point start
                    property point origin
                    onPressed: mouse => {
                        canvas.forceActiveFocus()
                        start = mapToItem(imageCanvas, mouse.x, mouse.y)
                        origin = Qt.point(root.regionX, root.regionY)
                    }
                    onPositionChanged: mouse => {
                        const position = mapToItem(imageCanvas, mouse.x, mouse.y)
                        if (root.magnifier) root.inspectPixel(position.x, position.y)
                        if (!pressed)
                            return
                        root.moveTo(origin.x + position.x - start.x, origin.y + position.y - start.y, true)
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
                                start = mapToItem(imageCanvas, mouse.x, mouse.y)
                                original = Qt.rect(root.regionX, root.regionY, root.regionWidth, root.regionHeight)
                            }
                            onPositionChanged: mouse => {
                                if (!pressed)
                                    return
                                const position = mapToItem(imageCanvas, mouse.x, mouse.y)
                                const dx = ScreenshotPrecision.snap(position.x - start.x, root.snapEnabled, root.gridSpacing)
                                const dy = ScreenshotPrecision.snap(position.y - start.y, root.snapEnabled, root.gridSpacing)
                                const hx = handle.modelData.hx
                                const hy = handle.modelData.hy
                                let left = original.x
                                let top = original.y
                                let right = original.x + original.width
                                let bottom = original.y + original.height
                                if (hx === 0) left = Math.max(0, Math.min(left + dx, right - root.dimensionStep))
                                if (hx === 1) right = Math.min(root.selectionSize.width, Math.max(right + dx, left + root.dimensionStep))
                                if (hy === 0) top = Math.max(0, Math.min(top + dy, bottom - root.dimensionStep))
                                if (hy === 1) bottom = Math.min(root.selectionSize.height, Math.max(bottom + dy, top + root.dimensionStep))
                                let w = right - left
                                let h = bottom - top
                                if (root.ratio > 0) {
                                    if (hx === 0.5) w = h * root.ratio
                                    else h = w / root.ratio
                                    const limitW = hx === 0 ? original.x + original.width : root.selectionSize.width - original.x
                                    const limitH = hy === 0 ? original.y + original.height : root.selectionSize.height - original.y
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
        }

        PixelMagnifier {
            visible: root.magnifier && root.inspectedPixel !== null
            pixel: root.inspectedPixel
            x: Math.max(8, Math.min(canvas.width - width - 8, root.pointerPosition.x + 24 + width < canvas.width
                ? root.pointerPosition.x + 24 : root.pointerPosition.x - width - 24))
            y: Math.max(8, Math.min(canvas.height - height - 8, root.pointerPosition.y + 24))
        }

        Rectangle {
            id: toolbar
            readonly property real regionLeft: (canvas.width - imageCanvas.width * root.previewScale) / 2 + root.regionX * root.previewScale
            readonly property real regionTop: (canvas.height - imageCanvas.height * root.previewScale) / 2 + root.regionY * root.previewScale
            readonly property real regionRight: regionLeft + root.regionWidth * root.previewScale
            readonly property real regionBottom: regionTop + root.regionHeight * root.previewScale
            readonly property real gap: 12
            width: Math.min(460, canvas.width - 16)
            height: controls.implicitHeight + 24
            x: regionRight + gap + width <= canvas.width
                ? regionRight + gap
                : regionLeft >= width + gap ? regionLeft - width - gap
                : Math.max(8, Math.min(regionLeft, canvas.width - width - 8))
            y: regionTop >= height + gap ? regionTop - height - gap
                : regionBottom + gap + height <= canvas.height
                    ? regionBottom + gap
                    : Math.max(8, Math.min(regionTop, canvas.height - height - 8))
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
                    text: root.validInputs ? qsTr("Drag to move or select. Arrows move by a pixel; Shift resizes, Ctrl+Shift resizes symmetrically.")
                        : root.dimensionStep === 2 ? qsTr("Enter even dimensions that fit on this screen.")
                        : qsTr("Enter pixel dimensions that fit on this screen.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Appearance.font.pixelSize.small
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    DialogButton { buttonText: qsTr("Select all"); onClicked: root.selectAll() }
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
