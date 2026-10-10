pragma Singleton

import qs.Modules.Common
import qs.Modules.Common.Functions
import qs.Modules.ScreenCapture
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property int countdown: 0
    property ShellScreen captureScreen
    property alias snapshotPath: session.snapshotPath
    property string outputPath: ""
    property string editorPath: ""
    readonly property string cacheDirectory: FileUtils.trimFileProtocol(`${Directories.cache}/carbon`)
    readonly property string screenshotDirectory: FileUtils.trimFileProtocol(`${Directories.pictures}/Screenshots`)
    readonly property bool busy: countdown > 0 || regionChooser.active || directoryProcess.running
        || snapshotProcess.running || cropProcess.running || output.busy || editor.active
    Component.onDestruction: removeSnapshot()

    PersistentProperties {
        id: session
        // Retain owned paths so a reload can clean up the previous session.
        reloadableId: "screenClipSession"
        property string snapshotPath: ""
    }

    Connections {
        target: Quickshell
        function onReloadCompleted(): void {
            root.cancel()
        }
    }

    function cancel(): void {
        countdownTimer.stop()
        countdown = 0
        directoryProcess.running = false
        snapshotProcess.running = false
        cropProcess.running = false
        output.cancel()
        regionChooser.active = false
        editor.active = false
        removeSnapshot()
        snapshotPath = ""
    }

    function open(delayed: bool): void {
        if (busy)
            return
        if (delayed) {
            countdown = 3
            countdownTimer.start()
        } else {
            takeSnapshot()
        }
    }

    function takeSnapshot(): void {
        captureScreen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        if (!captureScreen) {
            fail("Could not determine the active monitor")
            return
        }
        snapshotPath = `${cacheDirectory}/screen-clip-${Quickshell.processId}-${Date.now()}.png`
        directoryProcess.running = true
    }

    function removeSnapshot(): void {
        if (snapshotPath.length > 0) {
            Quickshell.execDetached(["rm", "-f", "--", snapshotPath, `${snapshotPath}.crop.png`])
        }
    }

    function editImage(path: string): void {
        if (busy || path.length === 0)
            return
        editorPath = path
        snapshotPath = FileUtils.trimFileProtocol(`${Directories.cache}/screenshot-render-${Quickshell.processId}-${Date.now()}.png`)
        editor.active = true
    }

    function fail(message: string): void {
        cancel()
        Quickshell.execDetached(["notify-send", "-a", "Screen clipping", "Screenshot failed", message])
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1
            if (root.countdown === 0) {
                stop()
                root.takeSnapshot()
            }
        }
    }

    Process {
        id: directoryProcess
        command: ["mkdir", "-p", root.cacheDirectory, root.screenshotDirectory]
        onExited: (exitCode, exitStatus) => {
            if (root.snapshotPath.length === 0)
                return
            if (exitCode !== 0) {
                root.fail("Could not create the screenshot directory")
                return
            }
            // Use the selector's coordinate scale so the saved dimensions match the pixel fields.
            snapshotProcess.command = ["grim", "-s", "1", "-o", root.captureScreen.name, root.snapshotPath]
            snapshotProcess.running = true
        }
    }

    Process {
        id: snapshotProcess
        onExited: (exitCode, exitStatus) => {
            if (root.snapshotPath.length === 0)
                return
            if (exitCode !== 0) {
                root.fail("Could not capture the screen")
                return
            }
            regionChooser.active = true
        }
    }

    Loader {
        id: regionChooser
        objectName: "screenClipSelection"
        active: false
        sourceComponent: RegionSelection {
            ratioIndex: 0
            initialSize: Qt.size(1080, 1080)
            screen: root.captureScreen
            backgroundSource: `file://${root.snapshotPath}`
            onCancelled: root.cancel()
            onAccepted: geometry => {
                const selection = regionChooser.item
                const crop = `${selection.regionWidth}x${selection.regionHeight}+${selection.regionX}+${selection.regionY}`
                const timestamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH.mm.ss.zzz")
                root.outputPath = `${root.screenshotDirectory}/Screenshot_${timestamp}.png`
                cropProcess.command = ["magick", root.snapshotPath, "-crop", crop, "+repage", `${root.snapshotPath}.crop.png`]
                regionChooser.active = false
                cropProcess.running = true
            }
        }
    }

    Process {
        id: cropProcess
        onExited: (exitCode, exitStatus) => {
            if (root.snapshotPath.length === 0)
                return
            if (exitCode !== 0) {
                root.fail("Could not save the selected region")
                return
            }
            output.saveFile(`${root.snapshotPath}.crop.png`, root.outputPath)
        }
    }

    ScreenshotOutput {
        id: output
        onFinished: root.cancel()
        onFailed: message => root.fail(message)
    }

    Loader {
        id: editor
        objectName: "screenClipEditor"
        active: false
        sourceComponent: ScreenshotEditor {
            imagePath: root.editorPath
            renderedPath: root.snapshotPath
            onCancelled: root.cancel()
            onSaved: root.cancel()
            onSaveFailed: root.removeSnapshot()
        }
    }

    IpcHandler {
        target: "screenClip"

        function editImage(path: string): void {
            root.editImage(path)
        }

        function open(): void {
            root.open(false)
        }

        function openDelayed(): void {
            root.open(true)
        }
    }
}
