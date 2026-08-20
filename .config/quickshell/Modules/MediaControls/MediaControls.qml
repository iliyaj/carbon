import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import "root:/Services"
import "root:/Modules/Common/Functions/string_utils.js" as StringUtils
import "root:/Modules/Common/Functions/file_utils.js" as FileUtils
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property bool visible: false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property var realPlayers: MprisController.players
    readonly property var meaningfulPlayers: filterDuplicatePlayers(realPlayers)
    readonly property real osdWidth: Appearance.sizes.osdWidth
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    property real contentPadding: 13
    property real popupRounding: Appearance.rounding.screenRounding - Appearance.sizes.elevationMargin + 1
    property real artRounding: Appearance.rounding.verysmall
    property list<real> visualizerPoints: []

    function normalizedTitle(player: MprisPlayer): string {
        return String(player.trackTitle ?? "").trim().toLowerCase()
    }

    function areDuplicatePlayers(first: MprisPlayer, second: MprisPlayer): bool {
        const firstTitle = normalizedTitle(first)
        const secondTitle = normalizedTitle(second)
        if (firstTitle.length === 0 || secondTitle.length === 0)
            return false

        const shorterTitle = firstTitle.length <= secondTitle.length ? firstTitle : secondTitle
        const longerTitle = firstTitle.length > secondTitle.length ? firstTitle : secondTitle
        const titlesMatch = firstTitle === secondTitle
            || (shorterTitle.length >= 8 && longerTitle.includes(shorterTitle))
        if (!titlesMatch)
            return false

        // Matching titles with substantially different durations can be
        // different recordings, not duplicate MPRIS endpoints.
        if (first.length > 0 && second.length > 0)
            return Math.abs(first.length - second.length) <= 2

        return true
    }

    function filterDuplicatePlayers(players) {
        let filtered = [];
        let used = new Set();

        for (let i = 0; i < players.length; ++i) {
            if (used.has(i)) continue;
            let p1 = players[i];
            let group = [i];

            // Match the same track symmetrically, independent of model order.
            for (let j = i + 1; j < players.length; ++j) {
                let p2 = players[j];
                if (areDuplicatePlayers(p1, p2)) {
                    group.push(j);
                }
            }

            // Pick the one with non-empty trackArtUrl, or fallback to the first
            let chosenIdx = group.find(idx => players[idx].trackArtUrl && players[idx].trackArtUrl.length > 0);
            if (chosenIdx === undefined) chosenIdx = group[0];

            filtered.push(players[chosenIdx]);
            group.forEach(idx => used.add(idx));
        }
        return filtered;
    }

    Process {
        id: cavaProc
        running: mediaControlsLoader.active
        onRunningChanged: {
            if (!cavaProc.running) {
                root.visualizerPoints = [];
            }
        }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.config)}/quickshell/Scripts/Cava/raw-output-config.conf`]
        stdout: SplitParser {
            onRead: data => {
                // Parse `;`-separated values into the visualizerPoints array
                let points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                root.visualizerPoints = points;
            }
        }
    }

    Loader {
        id: mediaControlsLoader
        active: false

        sourceComponent: PanelWindow {
            id: mediaControlsRoot
            visible: true

            exclusiveZone: 0
            implicitWidth: (
                (mediaControlsRoot.screen.width / 2) // Middle of screen
                    - (osdWidth / 2)                 // Dodge OSD
                    - (widgetWidth / 2)              // Account for widget width
            ) * 2
            implicitHeight: playerColumnLayout.implicitHeight
            color: "transparent"
            WlrLayershell.namespace: "quickshell:mediaControls"

            anchors {
                top: !ConfigOptions.bar.bottom
                bottom: ConfigOptions.bar.bottom
                left: true
            }
            mask: Region {
                item: playerColumnLayout
            }

            ColumnLayout {
                id: playerColumnLayout
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                x: (mediaControlsRoot.screen.width / 2)  // Middle of screen
                    - (osdWidth / 2)                     // Dodge OSD
                    - (widgetWidth)                      // Account for widget width
                    + (Appearance.sizes.elevationMargin) // It's fine for shadows to overlap
                spacing: -Appearance.sizes.elevationMargin // Shadow overlap okay

                Repeater {
                    model: ScriptModel {
                        values: root.meaningfulPlayers
                    }
                    delegate: PlayerControl {
                        required property MprisPlayer modelData
                        player: modelData
                        visualizerPoints: root.visualizerPoints
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "mediaControls"

        function toggle(): void {
            mediaControlsLoader.active = !mediaControlsLoader.active;
            if(mediaControlsLoader.active) Notifications.timeoutAll();
        }

        function close(): void {
            mediaControlsLoader.active = false;
        }

        function open(): void {
            mediaControlsLoader.active = true;
            Notifications.timeoutAll();
        }
    }

    GlobalShortcut {
        name: "mediaControlsToggle"
        description: qsTr("Toggles media controls on press")

        onPressed: {
            if (!mediaControlsLoader.active && MprisController.players.length === 0) {
                return;
            }
            mediaControlsLoader.active = !mediaControlsLoader.active;
            if(mediaControlsLoader.active) Notifications.timeoutAll();
        }
    }
    GlobalShortcut {
        name: "mediaControlsOpen"
        description: qsTr("Opens media controls on press")

        onPressed: {
            mediaControlsLoader.active = true;
            Notifications.timeoutAll();
        }
    }
    GlobalShortcut {
        name: "mediaControlsClose"
        description: qsTr("Closes media controls on press")

        onPressed: {
            mediaControlsLoader.active = false;
        }
    }

}
