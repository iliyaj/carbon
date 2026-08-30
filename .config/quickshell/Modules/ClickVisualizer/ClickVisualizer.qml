import "root:/Modules/Common"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: clickVisualizer

    signal clicked(real globalX, real globalY, string button)

    Process {
        command: ["python3", `${Directories.scriptPath}/Input/click_events.py`]
        running: true

        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line)
                    if (["left", "right", "middle"].indexOf(event.button) === -1
                            || !Number.isFinite(event.x) || !Number.isFinite(event.y)) {
                        console.warn("[ClickVisualizer] Ignoring invalid event:", line)
                        return
                    }
                    clickVisualizer.clicked(event.x, event.y, event.button)
                } catch (error) {
                    console.warn("[ClickVisualizer] Cannot parse event:", line, error)
                }
            }
        }
        stderr: SplitParser {
            onRead: line => console.warn(`[ClickVisualizer] ${line}`)
        }
        onExited: (exitCode, exitStatus) => {
            if (ConfigOptions.accessibility.showMouseClicks)
                console.error(`[ClickVisualizer] Input listener exited with code ${exitCode}`)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(window.screen)

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region { item: null }
            WlrLayershell.namespace: "quickshell:clickVisualizer"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            function showClick(globalX: real, globalY: real, button: string): void {
                if (!window.monitor)
                    return

                const localX = globalX - window.monitor.x
                const localY = globalY - window.monitor.y
                if (localX < 0 || localY < 0 || localX >= window.width || localY >= window.height)
                    return

                rippleComponent.createObject(rippleLayer, {
                    "clickX": localX,
                    "clickY": localY,
                    "button": button
                })
            }

            Connections {
                target: clickVisualizer
                function onClicked(globalX: real, globalY: real, button: string): void {
                    window.showClick(globalX, globalY, button)
                }
            }

            Item {
                id: rippleLayer
                anchors.fill: parent
            }

            Component {
                id: rippleComponent

                Item {
                    id: ripple

                    required property real clickX
                    required property real clickY
                    required property string button
                    readonly property color rippleColor: button === "right"
                        ? Appearance.m3colors.m3tertiary
                        : button === "middle"
                            ? Appearance.colors.colSecondary
                            : Appearance.colors.colPrimary

                    x: clickX - width / 2
                    y: clickY - height / 2
                    width: 48
                    height: 48

                    Rectangle {
                        id: contrastRing
                        anchors.centerIn: parent
                        width: 36
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 7
                        border.color: Appearance.m3colors.darkmode ? "#B3000000" : "#99FFFFFF"
                        scale: colourRing.scale
                        opacity: colourRing.opacity
                    }

                    Rectangle {
                        id: colourRing
                        anchors.centerIn: parent
                        width: 36
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 4
                        border.color: ripple.rippleColor
                    }

                    Rectangle {
                        id: centreFlash
                        anchors.centerIn: parent
                        width: 12
                        height: width
                        radius: width / 2
                        color: ripple.rippleColor
                    }

                    ParallelAnimation {
                        id: animation

                        NumberAnimation {
                            target: colourRing
                            property: "scale"
                            from: 0.65
                            to: 1.9
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: colourRing
                            property: "opacity"
                            from: 1
                            to: 0
                            duration: 400
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: centreFlash
                            property: "scale"
                            from: 1
                            to: 0.45
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: centreFlash
                            property: "opacity"
                            from: 0.9
                            to: 0
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                        onFinished: ripple.destroy()
                    }

                    Component.onCompleted: animation.start()
                }
            }
        }
    }
}
