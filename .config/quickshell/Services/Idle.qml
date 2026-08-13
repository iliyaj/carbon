pragma Singleton
pragma ComponentBehavior: Bound

import "root:/Modules/Common"
import QtQuick
import Quickshell
import Quickshell.Wayland

// Drives the Wayland idle-inhibit protocol directly, so the toggle state is a real property
Singleton {
    id: root

    readonly property bool inhibit: PersistentStates.idle.inhibit

    function toggleInhibit(active) {
        PersistentStateManager.setState("idle.inhibit", active === undefined ? !root.inhibit : active);
    }

    IdleInhibitor {
        enabled: root.inhibit
        // The protocol attaches to a surface, so hand it a zero-sized invisible one
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            anchors {
                right: true
                bottom: true
            }
            mask: Region {
                item: null
            }
        }
    }
}
