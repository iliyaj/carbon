import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    property int timeout: -1
    property bool executeLock: true

    signal triggered

    IdleMonitor {
        // Keep the monitor alive for "Never": this Quickshell build's enabled
        // getter is broken, so toggling it cannot be trusted.
        timeout: root.timeout >= 0 ? root.timeout : 2147483
        respectInhibitors: false
        onIsIdleChanged: {
            if (!isIdle || root.timeout < 0)
                return

            root.triggered()
            if (root.executeLock)
                Quickshell.execDetached(["loginctl", "lock-session"])
        }
    }
}
