import "root:/Modules/Common"
import "root:/Services"
import "root:/Modules/Common/Functions"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    readonly property var players: MprisController.players
    readonly property real osdWidth: Appearance.sizes.osdWidth
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    property real contentPadding: 13
    property real popupRounding: Appearance.rounding.screenRounding - Appearance.sizes.elevationMargin + 1
    property real artRounding: Appearance.rounding.verysmall
    property list<real> visualizerPoints: []

    function setOpen(open: bool): void {
        if (open && players.length === 0)
            return

        mediaControlsLoader.active = open
        if (open)
            Notifications.timeoutAll()
    }

    onPlayersChanged: {
        if (players.length === 0 && mediaControlsLoader.active)
            emptyCloseTimer.restart()
        else
            emptyCloseTimer.stop()
    }

    Timer {
        id: emptyCloseTimer
        interval: Appearance.animation.elementMoveExit.duration
        onTriggered: {
            if (root.players.length === 0)
                mediaControlsLoader.active = false
        }
    }

    Process {
        id: cavaProc
        running: mediaControlsLoader.active
        onRunningChanged: {
            if (!cavaProc.running)
                root.visualizerPoints = []
        }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.config)}/quickshell/Scripts/Cava/raw-output-config.conf`]
        stdout: SplitParser {
            onRead: data => {
                const points = data.split(";").map(point => parseFloat(point.trim())).filter(point => !isNaN(point))
                root.visualizerPoints = points
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
            implicitWidth: mediaControlsRoot.screen.width - osdWidth - widgetWidth
            implicitHeight: playerListView.retainedHeight
            color: "transparent"
            WlrLayershell.namespace: "quickshell:mediaControls"

            anchors {
                top: !ConfigOptions.bar.bottom
                bottom: ConfigOptions.bar.bottom
                left: true
            }
            mask: Region {
                item: playerInputRegion
            }

            Item {
                id: playerInputRegion
                x: playerListView.x
                width: playerListView.width
                height: playerListView.contentHeight
            }

            ListView {
                id: playerListView
                property real retainedHeight: 0

                x: mediaControlsRoot.screen.width / 2
                    - osdWidth / 2
                    - widgetWidth
                    + Appearance.sizes.elevationMargin
                width: widgetWidth
                height: retainedHeight
                interactive: false
                clip: false
                // Shadows overlap so adjacent cards keep their intended gap.
                spacing: -Appearance.sizes.elevationMargin

                onContentHeightChanged: retainedHeight = Math.max(retainedHeight, contentHeight)

                model: ScriptModel {
                    comparisonMode: ObjectComparison.Identity
                    values: root.players
                }
                delegate: PlayerControl {
                    required property MprisPlayer modelData
                    width: playerListView.width
                    height: implicitHeight
                    player: modelData
                    visualizerPoints: root.visualizerPoints
                }

                remove: Transition {
                    animations: [
                        NumberAnimation {
                            property: "scale"
                            to: 0.98
                            duration: Appearance.animation.elementMoveExit.duration
                            easing.type: Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
                        },
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: Appearance.animation.elementMoveExit.duration
                            easing.type: Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
                        }
                    ]
                }

                removeDisplaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "mediaControls"

        function toggle(): void {
            root.setOpen(!mediaControlsLoader.active)
        }

        function close(): void {
            root.setOpen(false)
        }

        function open(): void {
            root.setOpen(true)
        }
    }

    GlobalShortcut {
        name: "mediaControlsToggle"
        description: qsTr("Toggles media controls on press")

        onPressed: {
            root.setOpen(!mediaControlsLoader.active)
        }
    }
    GlobalShortcut {
        name: "mediaControlsOpen"
        description: qsTr("Opens media controls on press")

        onPressed: {
            root.setOpen(true)
        }
    }
    GlobalShortcut {
        name: "mediaControlsClose"
        description: qsTr("Closes media controls on press")

        onPressed: {
            root.setOpen(false)
        }
    }

}
