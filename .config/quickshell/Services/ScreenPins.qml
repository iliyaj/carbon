pragma Singleton

import qs.Modules.Common
import qs.Modules.ScreenCapture
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    readonly property string directory: (Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`) + "/carbon/screenshots/pins" // exporter-enforced
    property var pins: []
    property var owned: []
    property int serial: 0
    readonly property alias windows: pinWindows.instances
    property var formats: [{ id: "png", label: "PNG", extensions: ["png"] }]
    readonly property string prefix: `pin-${Quickshell.processId}-${Date.now()}-`

    readonly property bool dialogOpen: Array.from(windows).some(window => window.saveDialogOpen)

    PersistentProperties {
        id: resources
        reloadableId: "screenPinsResources"
        property list<string> paths: []
        onReloaded: {
            root.removeFiles(Array.from(paths));
            paths = root.owned;
        }
    }

    function clear(): void {
        for (const window of Array.from(windows)) window.cancelOutput();
        removeFiles(owned);
        pins = [];
        owned = [];
        resources.paths = [];
    }

    function removeFiles(paths): void {
        if (paths?.length > 0) Quickshell.execDetached(["rm", "-f", "--"].concat(paths));
    }

    function reserve(): string { // owned before export, so cancellation cannot orphan it
        serial += 1;
        const path = `${directory}/${prefix}${serial}.png`;
        owned = owned.concat([path]);
        resources.paths = owned;
        return path;
    }

    function show(path: string, originalPath: string): void {
        if (!owned.includes(path) || pins.some(pin => pin.path === path)) return;
        const screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        pins = pins.concat([{ path: path, original: originalPath, screen: screen?.name ?? "", cascade: pins.length % 8 }]);
    }

    function release(path: string): void {
        if (!owned.includes(path)) return;
        pins = pins.filter(pin => pin.path !== path);
        owned = owned.filter(entry => entry !== path);
        resources.paths = owned;
        removeFiles([path]);
    }

    Process {
        command: ["python3", `${Directories.scriptPath}/save-screenshot.py`, "--formats"]
        running: true
        stdout: StdioCollector { id: formatResult }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) return;
            try {
                const list = JSON.parse(formatResult.text);
                if (list.length > 0) root.formats = list;
            } catch (error) { console.warn("[ScreenPins] Invalid format list:", error); }
        }
    }

    Variants {
        id: pinWindows
        model: root.pins
        ScreenshotPin {}
    }
}
