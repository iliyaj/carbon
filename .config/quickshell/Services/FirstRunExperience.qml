pragma Singleton

import "root:/Modules/Common/Functions"
import "root:/Modules/Common"
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property string firstRunFilePath: `${Directories.state}/user/first_run.txt`
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property string firstRunNotifSummary: "Welcome!"
    property string firstRunNotifBody: "Hit Super+/ for a list of keybinds"
    property string defaultWallpaperPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/Assets/Images/default-wallpaper.webp`)
    property string welcomeQmlPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/welcome.qml`)

    function load() {
        firstRunFileView.reload()
    }

    function enableNextTime() {
        Quickshell.execDetached(["rm", "-f", root.firstRunFilePath])
    }
    function disableNextTime() {
        Quickshell.execDetached(["bash", "-c", `echo '${root.firstRunFileContent}' > '${root.firstRunFilePath}'`])
    }

    function handleFirstRun() {
        wallpaperCheck.running = true
        Quickshell.execDetached(["qs", "-p", root.welcomeQmlPath])
    }

    Process {
        id: wallpaperCheck
        command: ["awww", "query"]
        stdout: StdioCollector {
            id: wallpaperQueryOutput
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || !wallpaperQueryOutput.text.includes("image: "))
                Quickshell.execDetached([Directories.wallpaperToolPath, root.defaultWallpaperPath])
        }
    }

    FileView {
        id: firstRunFileView
        path: Qt.resolvedUrl(firstRunFilePath)
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) {
                firstRunFileView.setText(root.firstRunFileContent)
                root.handleFirstRun()
            }
        }
    }
}
