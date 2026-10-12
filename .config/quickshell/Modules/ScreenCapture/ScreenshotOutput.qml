import qs.Modules.Common
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    signal finished(string path, bool copied)
    signal failed(string message)
    readonly property bool busy: writer.running
    property string action: "save-copy"
    property string outputPath: ""
    property string originalPath: ""
    property bool cancelled: false

    function saveFile(source: string, destination: string): void {
        perform(source, "save-copy", destination, {});
    }

    function perform(source: string, operation: string, destination: string, options): void {
        if (busy) return;
        cancelled = false;
        action = operation;
        outputPath = "";
        writer.command = ["python3", `${Directories.scriptPath}/save-screenshot.py`, source, destination,
            "--action", operation, "--format", options.format ?? "png", "--quality", String(options.quality ?? 90),
            "--clipboard-format", options.clipboardFormat ?? "png"]
            .concat(originalPath.length > 0 ? ["--original", originalPath] : [])
            .concat(options.overwrite ? ["--overwrite"] : [])
            .concat(options.rotation ? ["--rotation", String(options.rotation)] : [])
            .concat(options.application ? ["--application", options.application] : []);
        if (ConfigOptions.screenshot.copyPathAfterSave && ["save", "save-copy"].includes(operation))
            writer.command = writer.command.concat(["--copy-path-after-save"]);
        writer.running = true;
    }

    function cancel(): void {
        cancelled = true;
        writer.running = false;
    }

    Component.onDestruction: cancel()

    Process {
        id: writer
        stdout: StdioCollector { id: result }
        stderr: StdioCollector { id: errors }
        onExited: (exitCode, exitStatus) => {
            if (root.cancelled) return;
            let response = {};
            try { response = JSON.parse(result.text); } catch (error) { /* Errors may have no result. */ }
            root.outputPath = response.path ?? "";
            if (exitCode !== 0) {
                root.failed(errors.text.trim() || qsTr("Screenshot export failed. Please try again."));
                return;
            }
            if (root.action === "pin") {
                root.finished(root.outputPath, false);
                return;
            }
            const messages = {
                "save": qsTr("Image saved to %1.").arg(root.outputPath),
                "save-copy": qsTr("Image saved to %1 and copied to the clipboard.").arg(root.outputPath),
                "copy": qsTr("Image copied to the clipboard."),
                "copy-path": qsTr("File path copied to the clipboard."),
                "open": qsTr("Image opened in the selected application.")
            };
            if (ConfigOptions.screenshot.notifications) Quickshell.execDetached(["notify-send", "-a", "Screen clipping"]
                .concat((root.action === "save" || root.action === "save-copy") && root.outputPath.length > 0
                    ? ["-i", root.outputPath] : [])
                .concat(["Screenshot", messages[root.action] ?? qsTr("Screenshot exported.")]));
            root.finished(root.outputPath, response.copied ?? false);
        }
    }
}
