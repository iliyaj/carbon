import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    readonly property string imagePath: Quickshell.env("ANNOTATE_IMG") ?? ""

    Component.onCompleted: {
        if (imagePath.length === 0) {
            console.warn("[annotator] No ANNOTATE_IMG provided, nothing to edit.")
            Qt.quit()
            return
        }
        launch.running = true
    }

    // Preserve existing launch commands while the shell owns annotation sessions.
    Process {
        id: launch
        command: ["qs", "ipc", "-p", Quickshell.shellPath("shell.qml"),
            "call", "screenClip", "editImage", root.imagePath]
        stderr: StdioCollector { id: errors }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.error("[annotator] Could not open the editor:", errors.text.trim())
            Qt.quit()
        }
    }
}
