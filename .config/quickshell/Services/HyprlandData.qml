pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var monitors: []
    readonly property var legacyEvents: [
        "activewindow", "focusedmon", "monitoradded",
        "createworkspace", "destroyworkspace", "moveworkspace",
        "activespecial", "movewindow", "windowtitle"
    ]

    function updateClients() {
        getClients.running = true
    }

    function updateMonitors() {
        getMonitors.running = true
    }

    function updateWindowList() {
        updateClients()
        updateMonitors()
    }

    Component.onCompleted: {
        updateWindowList()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // Active-window events repeat with animated titles; neither changes cached layout data.
            if (root.legacyEvents.includes(event.name)
                    || event.name === "activewindowv2"
                    || event.name === "windowtitlev2")
                return
            updateWindowList()
        }
    }

    Process {
        id: getClients
        command: ["bash", "-c", "hyprctl clients -j | jq -c"]
        stdout: SplitParser {
            onRead: (data) => {
                root.windowList = JSON.parse(data)
                let tempWinByAddress = {}
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i]
                    tempWinByAddress[win.address] = win
                }
                root.windowByAddress = tempWinByAddress
                root.addresses = root.windowList.map((win) => win.address)
            }
        }
    }
    Process {
        id: getMonitors
        command: ["bash", "-c", "hyprctl monitors -j | jq -c"]
        stdout: SplitParser {
            onRead: (data) => {
                root.monitors = JSON.parse(data)
            }
        }
    }
}
