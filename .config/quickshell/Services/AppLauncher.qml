pragma Singleton

import "root:/Modules/Common/Functions"
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

    // HyprlandToplevel reports a bare address while hyprctl and the dispatchers use the 0x form.
    function toplevelAddress(toplevel): string {
        const address = String(toplevel?.HyprlandToplevel?.address ?? "").replace(/^0x/, "");
        return address === "" ? "" : `0x${address}`;
    }

    // Carbon minimizes by parking a window on the special workspace.
    function isMinimized(toplevel): bool {
        const address = root.toplevelAddress(toplevel);
        if (address === "")
            return false;
        const windowData = HyprlandData.windowList.find(window => String(window.address ?? "") === address);
        return windowData?.workspace?.name === "special:special";
    }

    // Moves a minimized window back to the focused monitor before giving it focus.
    function restoreToplevel(toplevel): void {
        const address = root.toplevelAddress(toplevel);
        const workspaceId = HyprlandData.monitors.find(monitor => monitor.focused)?.activeWorkspace?.id;
        if (address === "" || workspaceId === undefined) {
            toplevel.activate();
            return;
        }

        const window = LuaUtils.stringLiteral(`address:${address}`);
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${workspaceId}, follow = false, window = ${window} })`);
        Hyprland.dispatch(`hl.dsp.focus({ window = ${window} })`);
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
        // A minimized window is a last resort, matching how the macOS dock prefers a visible one.
        return matches.sort((a, b) => (root.isMinimized(a) - root.isMinimized(b)) || (root.focusRank(a) - root.focusRank(b)));
    }

    // Single-instance apps exit silently when launched twice, so focus a live window first.
    function activateOrLaunch(entry): void {
        const matches = root.matchingToplevels(entry);
        if (matches.length > 0) {
            const toplevel = matches[0];
            if (root.isMinimized(toplevel))
                root.restoreToplevel(toplevel);
            else
                toplevel.activate();
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
