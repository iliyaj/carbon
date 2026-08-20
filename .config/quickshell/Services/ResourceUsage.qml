pragma Singleton
pragma ComponentBehavior: Bound

import "root:/Modules/Common"
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled RAM usage service.
 */
Singleton {
    property double memoryTotal: 1
    property double memoryFree: 1
    property double memoryUsed: memoryTotal - memoryFree
    property double memoryUsedPercentage: memoryUsed / memoryTotal

    Timer {
        interval: 1
        running: true
        repeat: true
        onTriggered: {
            // Reload files
            fileMeminfo.reload()

            // Parse memory usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)

            interval = ConfigOptions?.resources?.updateInterval ?? 3000
        }
    }

    FileView { id: fileMeminfo; path: "/proc/meminfo" }
}
