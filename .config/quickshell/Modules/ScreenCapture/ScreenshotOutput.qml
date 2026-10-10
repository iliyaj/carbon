import qs.Modules.Common
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    signal finished(string path, bool copied)
    signal failed(string message)
    readonly property bool busy: writer.running
    property string outputPath: ""
    property string backgroundPath: ""
    property bool cancelled: false

    function saveFile(source: string, destination: string): void {
        if (busy)
            return
        cancelled = false
        outputPath = destination
        writer.command = ["python3", `${Directories.scriptPath}/save-screenshot.py`, source, destination]
            .concat(backgroundPath.length > 0 ? ["--background", backgroundPath] : [])
        writer.running = true
    }

    function cancel(): void {
        cancelled = true
        writer.running = false
    }

    Component.onDestruction: cancel()

    Process {
        id: writer
        stderr: StdioCollector { id: errors }
        onExited: (exitCode, exitStatus) => {
            if (root.cancelled)
                return
            if (exitCode !== 0 && exitCode !== 2) {
                root.failed(errors.text.trim() || qsTr("Could not save the screenshot."))
                return
            }
            Quickshell.execDetached(["notify-send", "-a", "Screen clipping", "-i", root.outputPath,
                qsTr("Screenshot saved"), exitCode === 0 ? qsTr("Image saved and file path copied to the clipboard.")
                    : qsTr("Image saved, but file path copy failed.")])
            root.finished(root.outputPath, exitCode === 0)
        }
    }
}
