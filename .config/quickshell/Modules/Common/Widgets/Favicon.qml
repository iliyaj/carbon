import qs.Modules.Common
import qs.Modules.Common.Functions
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell.Io
import Quickshell.Widgets

IconImage {
    id: root
    property string url
    property string displayText

    property real size: 32
    property string downloadUserAgent: ConfigOptions?.networking.userAgent ?? ""
    property string faviconDownloadPath: Directories.favicons
    readonly property string domainName: root.url.includes("vertexaisearch") ? root.displayText : (StringUtils.getDomain(root.url) ?? "")

    Process {
        id: faviconDownloadProcess
        running: false
        command: ["python3", `${Directories.scriptPath}/Images/favicon.py`, "--",
            root.domainName, root.faviconDownloadPath, root.downloadUserAgent]
        stdout: StdioCollector {
            id: downloadOutput
        }
        onExited: (exitCode, exitStatus) => {
            root.source = exitCode === 0 && exitStatus === 0 ? downloadOutput.text.trim() : ""
        }
    }

    Component.onCompleted: {
        faviconDownloadProcess.running = root.domainName.length > 0
    }

    source: ""
    implicitSize: root.size

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.implicitSize
            height: root.implicitSize
            radius: Appearance.rounding.full
        }
    }
}
