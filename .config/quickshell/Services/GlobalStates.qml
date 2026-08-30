import "root:/Modules/Common/"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property bool sidebarLeftOpen: false
    property bool sidebarRightOpen: false
    property bool overviewOpen: false
    property bool workspaceShowNumbers: false
    property bool gameMode: false

    function applyGameMode(): void {
        Hyprland.dispatch("function() hl.config({ animations = { enabled = false }, decoration = { shadow = { enabled = false }, blur = { enabled = false }, rounding = 0 }, general = { gaps_in = 0, gaps_out = 0, border_size = 1, allow_tearing = true } }) end");
    }

    // Strips the compositor's eye candy; shell surfaces watch gameMode to drop their own rounding
    function setGameMode(enabled: bool): void {
        root.gameMode = enabled;
        if (enabled)
            root.applyGameMode();
        else
            Quickshell.execDetached(["hyprctl", "reload"]);
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded" && root.gameMode)
                root.applyGameMode();
        }
    }

    // Game mode outlives the shell, so recover it from the compositor instead of assuming it is off
    Process {
        running: true
        command: ["hyprctl", "getoption", "animations:enabled", "-j"]
        stdout: StdioCollector {
            id: animationsOption
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                return;
            try {
                root.gameMode = !JSON.parse(animationsOption.text).bool;
            } catch (e) {
                console.error("[GlobalStates] Failed to parse Hyprland animation state:", e);
            }
        }
    }

    Timer {
        id: workspaceShowNumbersTimer
        interval: ConfigOptions.bar.workspaces.showNumberDelay
        // interval: 0
        repeat: false
        onTriggered: {
            workspaceShowNumbers = true
        }
    }

    GlobalShortcut {
        name: "gameModeToggle"
        description: qsTr("Toggle game mode")

        onPressed: {
            root.setGameMode(!root.gameMode)
        }
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: qsTr("Hold to show workspace numbers, release to show icons")

        onPressed: {
            workspaceShowNumbersTimer.start()
        }
        onReleased: {
            workspaceShowNumbersTimer.stop()
            workspaceShowNumbers = false
        }
    }
}
