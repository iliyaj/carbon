pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Keybinds for the cheatsheet, read straight from the compositor.
 *
 * Replaces get_keybinds.py, which regex-parsed the .conf files for `#!` section
 * headings, `# [hidden]` markers and trailing `# comment` descriptions. Lua has
 * no comments to parse, so that metadata now lives in each bind's own
 * `description` as "Category: label", and a bind with no description is hidden.
 *
 * Everything the view needs is derived here, so the view stays a dumb renderer.
 */
Singleton {
    id: root

    // [{ name: string, binds: [{ mods: [string], key: string, label: string }] }]
    property var sections: []

    // hyprctl reports modifiers as a bitmask. Listed in user-facing order,
    // which is deliberately not numeric order.
    readonly property var modifiers: [
        { bit: 1 << 2, name: "Ctrl" },
        { bit: 1 << 6, name: "Super" },
        { bit: 1 << 0, name: "Shift" },
        { bit: 1 << 3, name: "Alt" },
        { bit: 1 << 1, name: "Caps" },
        { bit: 1 << 4, name: "Mod2" },
        { bit: 1 << 5, name: "Mod3" },
        { bit: 1 << 7, name: "Mod5" },
    ]

    function modsOf(mask: int): var {
        return root.modifiers.filter(m => mask & m.bit).map(m => m.name);
    }

    function rebuild(json: string) {
        const order = [];
        const grouped = ({});

        for (const bind of JSON.parse(json)) {
            const description = bind.description ?? "";
            if (description.length === 0)
                continue; // no description means hidden, by convention

            const colon = description.indexOf(":");
            const section = colon > 0 ? description.slice(0, colon) : qsTr("Other");
            const label = colon > 0 ? description.slice(colon + 1).trim() : description;

            if (!grouped[section]) {
                grouped[section] = [];
                order.push(section);
            }
            grouped[section].push({
                mods: root.modsOf(bind.modmask),
                key: bind.key,
                label: label,
            });
        }

        root.sections = order.map(name => ({ name: name, binds: grouped[name] }));
    }

    Process {
        id: readBinds
        running: true
        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.rebuild(text);
                } catch (e) {
                    console.error("[HyprlandKeybinds] could not parse hyprctl binds:", e);
                }
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded")
                readBinds.running = true;
        }
    }
}
