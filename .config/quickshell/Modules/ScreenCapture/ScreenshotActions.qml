pragma ComponentBehavior: Bound

import qs.Modules.Common
import qs.Services
import "screenshot_preferences.js" as ScreenshotPreferences
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs as NativeDialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool ready: false
    property bool busy: false
    property string savedPath: ""
    property string directory: {
        if (ConfigOptions.screenshot.directory) return ConfigOptions.screenshot.directory;
        const url = Directories.pictures.toString();
        return decodeURIComponent(url.replace(/^file:\/\//, "")) + "/Screenshots";
    }
    property string filenamePattern: ConfigOptions.screenshot.filenamePattern
    property int formatIndex: Math.max(0, formats.findIndex(format => format.id === ConfigOptions.screenshot.format))
    property int quality: ConfigOptions.screenshot.quality
    property string clipboardFormat: ConfigOptions.screenshot.clipboardFormat
    property var formats: [
        { id: "png", label: "PNG", extensions: ["png"] },
        { id: "jpeg", label: "JPEG", extensions: ["jpg", "jpeg"] }
    ]
    readonly property var imageFormat: formats[formatIndex] ?? formats[0]
    signal requested(string action, string destination, var options)
    signal invalid(string message)
    implicitWidth: actionRow.implicitWidth
    implicitHeight: actionRow.implicitHeight

    function fileUrl(path): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function options() {
        return { format: imageFormat.id, quality: quality, clipboardFormat: clipboardFormat };
    }

    function openWith(): void { applicationDialog.open(); }
    function showOptions(): void { optionsDialog.open(); }
    function copyPath(): void { requested("copy-path", savedPath, options()); }

    function requestCopy(): void {
        if (ConfigOptions.screenshot.saveAfterCopy) requestSave("save-copy");
        else requested("copy", "", options());
    }

    function setPreference(key, value): void {
        try {
            ScreenshotPreferences.validate({ [key]: value });
            ConfigLoader.setConfigValueAndSave("screenshot." + key, value);
        } catch (error) { invalid(error.message); }
    }

    function requestSave(action): void {
        const filename = Qt.formatDateTime(new Date(), filenamePattern);
        if (!directory.startsWith("/") || filename.length === 0 || /[/\\]/.test(filename) || filename === "." || filename === "..") {
            invalid(qsTr("Choose an absolute destination folder and a filename pattern without slashes."));
            return;
        }
        requested(action, directory + "/" + filename + "." + imageFormat.extensions[0], options());
    }

    function saveAs(): void {
        fileDialog.currentFolder = fileUrl(directory);
        fileDialog.selectedNameFilter.index = formatIndex;
        fileDialog.open();
    }

    RowLayout {
        id: actionRow
        anchors.fill: parent
        spacing: 4

        ScreenshotActionButton {
            text: qsTr("Copy image")
            enabled: root.ready && !root.busy
            onClicked: root.requestCopy()
        }
        ScreenshotActionButton {
            text: qsTr("Save")
            enabled: root.ready && !root.busy
            onClicked: root.requestSave("save")
        }
        ScreenshotActionButton {
            text: qsTr("Save as…")
            enabled: root.ready && !root.busy
            onClicked: root.saveAs()
        }
        ScreenshotActionButton {
            text: qsTr("Save + copy")
            enabled: root.ready && !root.busy
            onClicked: root.requestSave("save-copy")
        }
        ScreenshotActionButton {
            text: qsTr("Copy file path")
            enabled: root.savedPath.length > 0 && !root.busy
            onClicked: root.requested("copy-path", root.savedPath, root.options())
        }
        ScreenshotActionButton {
            text: qsTr("Pin")
            enabled: root.ready && !root.busy
            onClicked: root.requested("pin", "", root.options())
        }
        ScreenshotActionButton {
            text: qsTr("Open with…")
            enabled: root.ready && !root.busy
            onClicked: applicationDialog.open()
        }
        ScreenshotActionButton {
            text: qsTr("Output options…")
            enabled: !root.busy
            onClicked: optionsDialog.open()
        }
    }

    Process {
        id: formatProbe
        command: ["python3", `${Directories.scriptPath}/save-screenshot.py`, "--formats"]
        running: true
        stdout: StdioCollector { id: formatResult }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) return;
            try {
                const list = JSON.parse(formatResult.text);
                if (list.length > 0) root.formats = list;
            } catch (error) { console.warn("[ScreenshotActions] Invalid format list:", error); }
        }
    }

    NativeDialogs.FileDialog {
        id: fileDialog
        title: qsTr("Save screenshot as")
        fileMode: NativeDialogs.FileDialog.SaveFile
        nameFilters: root.formats.map(f => f.label + " (" + f.extensions.map(e => "*." + e).join(" ") + ")")
        defaultSuffix: root.formats[selectedNameFilter.index]?.extensions[0] ?? "png"
        onAccepted: {
            const destination = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""));
            root.formatIndex = selectedNameFilter.index;
            // SaveFile's native dialog confirms replacement before acceptance.
            root.requested("save", destination, Object.assign(root.options(), { overwrite: true }));
        }
    }

    NativeDialogs.FolderDialog {
        id: folderDialog
        title: qsTr("Screenshot destination")
        onAccepted: root.setPreference("directory", decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, "")))
    }

    Dialog {
        id: optionsDialog
        parent: Overlay.overlay
        title: qsTr("Screenshot output options")
        modal: true
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: Math.min(460, parent.width - 24)
        standardButtons: Dialog.Close
        footer: DialogButtonBox {
            delegate: ScreenshotActionButton {}
        }

        contentItem: ColumnLayout {
            spacing: 10
            Label { text: qsTr("Destination folder") }
            RowLayout {
                Layout.fillWidth: true
                TextField {
                    Layout.fillWidth: true
                    text: root.directory
                    onEditingFinished: root.setPreference("directory", text)
                }
                ScreenshotActionButton {
                    text: qsTr("Choose…")
                    onClicked: {
                        folderDialog.currentFolder = root.fileUrl(root.directory);
                        folderDialog.open();
                    }
                }
            }
            Label { text: qsTr("Filename pattern (Qt date format)") }
            TextField {
                Layout.fillWidth: true
                text: root.filenamePattern
                placeholderText: "'Screenshot_'yyyy-MM-dd_HH.mm.ss.zzz"
                onEditingFinished: root.setPreference("filenamePattern", text)
            }
            RowLayout {
                Label { text: qsTr("File format") }
                ComboBox {
                    Layout.fillWidth: true
                    model: root.formats
                    textRole: "label"
                    currentIndex: root.formatIndex
                    onActivated: index => root.setPreference("format", root.formats[index].id)
                }
            }
            RowLayout {
                Label { text: qsTr("JPEG / WebP / AVIF quality") }
                SpinBox {
                    from: 1
                    to: 100
                    value: root.quality
                    editable: true
                    onValueModified: root.setPreference("quality", value)
                }
            }
            RowLayout {
                Label { text: qsTr("Image clipboard format") }
                ComboBox {
                    model: ["PNG", "JPEG"]
                    currentIndex: root.clipboardFormat === "jpeg" ? 1 : 0
                    onActivated: index => root.setPreference("clipboardFormat", index === 1 ? "jpeg" : "png")
                }
            }
        }
    }

    Dialog {
        id: applicationDialog
        parent: Overlay.overlay
        title: qsTr("Open screenshot with")
        modal: true
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: Math.min(420, parent.width - 24)
        standardButtons: Dialog.Open | Dialog.Cancel
        footer: DialogButtonBox {
            delegate: ScreenshotActionButton {}
        }
        onAccepted: root.requested("open", "", Object.assign(root.options(), { application: applicationBox.model[applicationBox.currentIndex]?.id ?? "" }))

        contentItem: ComboBox {
            id: applicationBox
            textRole: "name"
            model: [{ name: qsTr("System default application"), id: "" }].concat(
                Array.from(DesktopEntries.applications.values).filter(entry => !entry.noDisplay && /%[fFuU]/.test(entry.execString))
                    .map(entry => ({ name: entry.name, id: entry.id })).sort((a, b) => a.name.localeCompare(b.name)))
        }
    }

}
