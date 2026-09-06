pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Singleton {
    id: root

    // Lowercased names an app's windows may report as their appId, most specific first.
    function windowKeys(entry): var {
        if (!entry)
            return [];

        const keys = [];
        for (const value of [entry.startupClass, entry.id, entry.name]) {
            const key = String(value ?? "").replace(/\.desktop$/, "").toLowerCase();
            if (key === "")
                continue;
            if (!keys.includes(key))
                keys.push(key);
            const tail = key.split(".").pop();
            if (tail !== key && !keys.includes(tail))
                keys.push(tail);
        }
        return keys;
    }

    // Addresses of windows focused this session, most recent first.
    property var focusOrder: []

    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            const address = root.toplevelAddress(ToplevelManager.activeToplevel);
            if (address === "")
                return;
            root.focusOrder = [address].concat(root.focusOrder.filter(other => other !== address));
        }
    }

    function toplevelAddress(toplevel): string {
        return String(toplevel?.HyprlandToplevel?.address ?? "");
    }

    // Sorts behind every window the compositor still remembers being focused.
    readonly property int unknownFocusRank: 9999

    // Ranks a window by how recently it held focus, lower being more recent.
    function focusRank(toplevel): real {
        const index = root.focusOrder.indexOf(root.toplevelAddress(toplevel));
        if (index >= 0)
            return index;
        const historyId = toplevel?.HyprlandToplevel?.lastIpcObject?.focusHistoryID;
        return root.focusOrder.length + (historyId ?? root.unknownFocusRank);
    }

    function matchingToplevels(entry): var {
        const keys = root.windowKeys(entry);
        if (keys.length === 0)
            return [];

        const matches = [];
        for (const toplevel of ToplevelManager.toplevels.values) {
            const appId = String(toplevel.appId ?? "").toLowerCase();
            if (appId === "")
                continue;
            if (keys.includes(appId) || keys.includes(appId.split(".").pop()))
                matches.push(toplevel);
        }
        return matches.sort((a, b) => root.focusRank(a) - root.focusRank(b));
    }

    // Single-instance apps exit silently when launched twice, so focus a live window first.
    function activateOrLaunch(entry): void {
        const matches = root.matchingToplevels(entry);
        if (matches.length > 0) {
            matches[0].activate();
            return;
        }
        root.launchDesktopEntry(entry);
    }

    // Keep GUI applications outside quickshell.service so a shell restart cannot kill them.
    function launchDesktopEntry(entry): void {
        if (!entry)
            return;

        const desktopId = String(entry.id ?? "").replace(/\.desktop$/, "");
        if (desktopId !== "") {
            Quickshell.execDetached([
                "systemd-run", "--user", "--scope", "--collect",
                "--slice=app.slice", "--", "gtk-launch", desktopId
            ]);
            return;
        }

        launchCommand(entry.exec);
    }

    function launchCommand(command): void {
        if (!command || command.length === 0)
            return;

        Quickshell.execDetached([
            "systemd-run", "--user", "--scope", "--collect",
            "--slice=app.slice", "--"
        ].concat(command));
    }
}
