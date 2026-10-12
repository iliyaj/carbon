pragma ComponentBehavior: Bound

import qs.Modules.Common
import qs.Modules.Common.Widgets
import qs.Modules.Common.Functions
import qs.Services
import "capture_geometry.js" as CaptureGeometry
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    required property var owner
    required property string sessionId
    required property var request
    required property string scratchPath
    property string imagePath: ""
    property string state: "new"
    property int countdown: 0
    property var capturedLayout: []
    property var area: null
    property ShellScreen chooserScreen
    property string monitorName: ""
    property alias selector: regionChooser.item
    property alias editorWindow: editor.item
    property rect initialRegion: Qt.rect(0, 0, 0, 0)
    property var selectedRegion: null
    property string resultState: "cancelled"
    property string errorMessage: ""
    property string savedPath: ""
    property string pendingPin: ""
    property string resultPin: ""
    property bool copied: false
    property var remainingOutputs: []
    property string exportSource: ""
    readonly property bool terminal: ["completed", "cancelled", "failed"].includes(state)
    readonly property string snapshotPath: scratchPath + ".ppm"
    readonly property string cropPath: scratchPath + ".crop.png"
    readonly property string renderedPath: scratchPath + ".render.png"
    readonly property var ownedPaths: [snapshotPath, cropPath, renderedPath]
    readonly property bool closing: state === "closing" || terminal
    readonly property bool processesRunning: layoutProcess.running || directoryProcess.running
        || snapshotProcess.running || cropProcess.running || output.busy || (editor.item?.exporting ?? false)
    signal finished(string sessionId)
    signal failed(string message)
    onProcessesRunningChanged: { if (closing) completeClose() }

    function start(): void {
        if (imagePath.length > 0) {
            state = "preparing"
            directoryProcess.running = true
        } else if (request.delay > 0) {
            countdown = request.delay
            state = "delay"
            countdownTimer.start()
        } else takeSnapshot()
    }

    function takeSnapshot(): void {
        if (owner.sessions.some(session => session.state === "selecting")) {
            state = "waiting-capture"
            return
        }
        state = "preparing"
        layoutProcess.running = true
    }

    function cancel(): void {
        if (closing) return
        state = "closing"
        countdownTimer.stop()
        countdown = 0
        regionChooser.active = false
        if (editor.item) {
            editor.item.prepareClose()
            editor.item.cancelOutput()
            editor.item.visible = false
        }
        layoutProcess.running = false
        directoryProcess.running = false
        snapshotProcess.running = false
        cropProcess.running = false
        output.cancel()
        if (pendingPin) { ScreenPins.release(pendingPin); pendingPin = "" }
        completeClose()
    }

    function completeClose(): void {
        if (state !== "closing" || processesRunning) return
        editor.active = false
        state = resultState
        finished(sessionId)
    }

    function fail(message): void {
        errorMessage = message
        resultState = "failed"
        failed(message)
        cancel()
    }

    function result() {
        return { id: sessionId, state: state, error: errorMessage, path: savedPath, copied: copied,
            pin: resultPin, image: resultState === "completed" ? exportSource : "",
            region: selectedRegion, monitor: monitorName, area: area }
    }

    function finishEditing(): void {
        if (!editor.item?.renderImage(renderedPath)) { fail("Could not render the screenshot."); return }
        exportImage(renderedPath)
    }

    function exportImage(source): void {
        exportSource = source
        state = "exporting"
        remainingOutputs = (request.outputs ?? ["save", "copy"]).slice()
        nextOutput()
    }

    function nextOutput(): void {
        if (remainingOutputs.length === 0) {
            resultState = "completed"
            cancel()
            return
        }
        let action = remainingOutputs[0]
        remainingOutputs = remainingOutputs.slice(1)
        if (action === "save" && remainingOutputs.includes("copy")) {
            action = "save-copy"
            remainingOutputs = remainingOutputs.filter(item => item !== "copy")
        }
        let destination = ""
        if (action === "save" || action === "save-copy") {
            const filename = Qt.formatDateTime(new Date(), ConfigOptions.screenshot.filenamePattern)
            if (!filename || /[/\\]/.test(filename) || filename === "." || filename === "..") { fail("Invalid screenshot filename pattern."); return }
            destination = request.path || owner.screenshotDirectory + "/" + filename + "_" + sessionId + "." + (request.format === "jpeg" ? "jpg" : request.format ?? "png")
        }
        if (action === "pin") destination = pendingPin = ScreenPins.reserve()
        output.perform(exportSource, action, destination, request)
    }

    function ready(): void {
        if (closing) return
        const width = frozenImage.sourceSize.width
        const height = frozenImage.sourceSize.height
        let region = request.region
        try {
            if (request.selection === "last")
                region = CaptureGeometry.rememberedRegion(owner.lastRegion, request.target === "desktop" ? "desktop" : "monitor",
                    monitorName, area, width, height)
            else if (region && !CaptureGeometry.validRegion(region, width, height))
                throw new Error("The initial region is outside the captured image.")
            if (request.selection === "all") region = { x: 0, y: 0, width: width, height: height }
            if (region) initialRegion = Qt.rect(region.x, region.y, region.width, region.height)
        } catch (error) { fail(error.message); return }
        if (request.selection === "all" || request.selection === "last") {
            acceptRegion(initialRegion)
        } else {
            state = "waiting"
            owner.showNextSelection()
        }
    }

    function select(): void {
        if (state !== "waiting") return
        state = "selecting"
        regionChooser.active = true
    }

    function acceptRegion(region): void {
        if (closing) return
        if (!CaptureGeometry.validRegion(region, frozenImage.sourceSize.width, frozenImage.sourceSize.height)) {
            fail("The selected region is outside the captured image.")
            return
        }
        selectedRegion = { x: region.x, y: region.y, width: region.width, height: region.height }
        owner.remember({ target: request.target === "desktop" ? "desktop" : "monitor", monitor: monitorName,
            signature: area.signature, imageWidth: frozenImage.sourceSize.width,
            imageHeight: frozenImage.sourceSize.height,
            region: { x: region.x, y: region.y, width: region.width, height: region.height } })
        regionChooser.active = false
        state = "cropping"
        cropProcess.command = ["magick", snapshotPath, "-crop", `${region.width}x${region.height}+${region.x}+${region.y}`, "+repage", cropPath]
        cropProcess.running = true
        owner.showNextSelection()
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown--
            if (root.countdown === 0) {
                stop()
                root.takeSnapshot()
            }
        }
    }

    PanelWindow {
        visible: root.countdown > 0 && !root.owner.sessions.some(session => ["preparing", "capturing"].includes(session.state))
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; right: true }
        margins { top: 56; right: 16 }
        implicitWidth: 280
        implicitHeight: 64
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:screenCapture"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.m3colors.m3surfaceContainerHigh
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                text: qsTr("Capture in %1 s").arg(root.countdown)
                color: Appearance.m3colors.m3onSurface
            }
            DialogButton {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                buttonText: qsTr("Cancel")
                onClicked: root.cancel()
            }
        }
    }

    Process {
        id: layoutProcess
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { id: layoutResult }
        onExited: (exitCode, exitStatus) => {
            if (root.closing) { root.completeClose(); return }
            if (exitCode !== 0) { root.fail("Could not read the monitor layout."); return }
            try {
                root.capturedLayout = CaptureGeometry.layout(JSON.parse(layoutResult.text), Array.from(Quickshell.screens))
                root.monitorName = root.request.target === "monitor" ? root.request.monitor
                    : root.request.target === "desktop" ? "" : Hyprland.focusedMonitor?.name ?? ""
                root.area = CaptureGeometry.captureArea(root.capturedLayout, root.request.target, root.monitorName)
                root.chooserScreen = Quickshell.screens.find(s => s.name === (root.monitorName || Hyprland.focusedMonitor?.name)) ?? Quickshell.screens[0]
                if (!root.chooserScreen) throw new Error("No screen is available for selection.")
            } catch (error) { root.fail(error.message); return }
            directoryProcess.running = true
        }
    }

    Process {
        id: directoryProcess
        command: ["mkdir", "-p", root.owner.cacheDirectory]
        onExited: (exitCode, exitStatus) => {
            if (root.closing) { root.completeClose(); return }
            if (exitCode !== 0) { root.fail("Could not create the capture cache."); return }
            if (root.imagePath.length > 0) {
                root.state = "editing"
                editor.active = true
                root.owner.showNextSelection()
                return
            }
            // The frozen working image needs exact pixels, not compression before selection.
            snapshotProcess.command = ["grim", "-t", "ppm", "-s", String(root.area.scale)]
                .concat(root.request.target === "desktop" ? [] : ["-o", root.monitorName])
                .concat([root.snapshotPath])
            root.state = "capturing"
            snapshotProcess.running = true
        }
    }

    Process {
        id: snapshotProcess
        stderr: StdioCollector { id: captureErrors }
        onExited: (exitCode, exitStatus) => {
            if (root.closing) { root.completeClose(); return }
            if (exitCode !== 0) { root.fail(captureErrors.text.trim() || "Could not capture the screen."); return }
            frozenImage.source = "file://" + root.snapshotPath.split("/").map(encodeURIComponent).join("/")
        }
    }

    Image {
        id: frozenImage
        visible: false
        cache: false
        onStatusChanged: {
            if (status === Image.Ready) root.ready()
            else if (status === Image.Error && !root.closing) root.fail("Could not load the frozen screenshot.")
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            if (root.area && ["selecting", "waiting"].includes(root.state)) root.fail("The monitor layout changed during capture. Try again.")
        }
    }

    Loader {
        id: regionChooser
        objectName: "screenClipSelection"
        active: false
        sourceComponent: RegionSelection {
            screenshotMode: true
            ratioIndex: 0
            initialSize: Qt.size(1080, 1080)
            initialRegion: root.initialRegion
            selectionSize: frozenImage.sourceSize
            acceptOnSelection: root.request.acceptOnSelection
            acceptText: root.request.edit ? qsTr("Edit screenshot") : qsTr("Capture screenshot")
            screen: root.chooserScreen
            backgroundSource: frozenImage.source
            onCancelled: root.cancel()
            onAccepted: geometry => {
                const item = regionChooser.item
                root.acceptRegion({ x: item.regionX, y: item.regionY, width: item.regionWidth, height: item.regionHeight })
            }
        }
    }

    Process {
        id: cropProcess
        onExited: (exitCode, exitStatus) => {
            if (root.closing) { root.completeClose(); return }
            if (exitCode !== 0) { root.fail("Could not crop the selected region."); return }
            root.imagePath = root.cropPath
            if (root.request.edit) {
                root.state = "editing"
                editor.active = true
            } else {
                root.exportImage(root.cropPath)
            }
        }
    }

    ScreenshotOutput {
        id: output
        onFinished: (path, copied) => {
            if (output.action === "save" || output.action === "save-copy") root.savedPath = path
            if (output.action === "copy" || output.action === "save-copy") root.copied = copied
            if (output.action === "pin") {
                ScreenPins.show(root.pendingPin, root.imagePath)
                root.resultPin = root.pendingPin
                root.pendingPin = ""
            }
            Qt.callLater(root.nextOutput)
        }
        onFailed: message => root.fail(message)
    }

    Loader {
        id: editor
        objectName: "screenClipEditor"
        active: false
        sourceComponent: ScreenshotEditor {
            imagePath: root.imagePath
            renderedPath: root.renderedPath
            automation: root.request.wait ?? false
            onLoadFailed: message => root.fail(message)
            onRenderReadyChanged: {
                if (renderReady && root.selectedRegion === null)
                    root.selectedRegion = { x: 0, y: 0, width: imageSize.width, height: imageSize.height }
            }
            onAccepted: root.finishEditing()
            onCancelled: root.cancel()
            onSaved: {
                if (root.request.wait) root.finishEditing()
                else root.cancel()
            }
            onSaveFailed: Quickshell.execDetached(["rm", "-f", "--", root.renderedPath])
        }
    }
}
