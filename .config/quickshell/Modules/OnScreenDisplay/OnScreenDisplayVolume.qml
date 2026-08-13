import "root:/Services/"
import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property bool showOsdValues: false
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
    // Derived from the volume rather than latched on the signal, so it clears as soon as you turn it down
    readonly property bool atVolumeLimit: ConfigOptions.audio.protection.enable
        && (Audio.sink?.audio.volume ?? 0) >= (ConfigOptions.audio.protection.maxAllowed / 100) - 0.001

    function triggerOsd() {
        showOsdValues = true
        osdTimeout.restart()
    }

    Timer {
        id: osdTimeout
        interval: ConfigOptions.osd.timeout
        repeat: false
        running: false
        onTriggered: root.showOsdValues = false
    }

    Connections {
        target: Brightness
        function onBrightnessChanged() {
            showOsdValues = false
        }
    }

    Connections { // Listen to volume changes
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() {
            if (!Audio.ready) return
            root.triggerOsd()
        }
        function onMutedChanged() {
            if (!Audio.ready) return
            root.triggerOsd()
        }
    }

    Connections { // Show the OSD even when a change was rejected outright
        target: Audio
        function onSinkProtectionTriggered() {
            root.triggerOsd()
        }
    }

    Loader {
        id: osdLoader
        active: showOsdValues

        sourceComponent: PanelWindow {
            id: osdRoot

            Connections {
                target: root
                function onFocusedScreenChanged() {
                    osdRoot.screen = root.focusedScreen
                }
            }

            exclusionMode: ExclusionMode.Normal
            WlrLayershell.namespace: "quickshell:onScreenDisplay"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            anchors {
                top: !ConfigOptions.bar.bottom
                bottom: ConfigOptions.bar.bottom
            }
            mask: Region {
                item: osdValuesWrapper
            }

            implicitWidth: columnLayout.implicitWidth
            implicitHeight: columnLayout.implicitHeight
            visible: osdLoader.active

            ColumnLayout {
                id: columnLayout
                anchors.horizontalCenter: parent.horizontalCenter
                Item {
                    id: osdValuesWrapper
                    // Extra space for shadow
                    implicitHeight: contentColumnLayout.implicitHeight + Appearance.sizes.elevationMargin * 2
                    implicitWidth: contentColumnLayout.implicitWidth
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.showOsdValues = false
                    }

                    ColumnLayout {
                        id: contentColumnLayout
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            leftMargin: Appearance.sizes.elevationMargin
                            rightMargin: Appearance.sizes.elevationMargin
                        }
                        spacing: 0

                        OsdValueIndicator {
                            id: osdValues
                            Layout.fillWidth: true
                            value: Audio.sink?.audio.volume ?? 0
                            icon: Audio.sink?.audio.muted ? "volume_off" : "volume_up"
                            name: qsTr("Volume")
                            alert: root.atVolumeLimit
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
		target: "osdVolume"

		function trigger() {
            root.triggerOsd()
        }

        function hide() {
            showOsdValues = false
        }

        function toggle() {
            showOsdValues = !showOsdValues
        }
	}
    GlobalShortcut {
        name: "osdVolumeTrigger"
        description: qsTr("Triggers volume OSD on press")

        onPressed: {
            root.triggerOsd()
        }
    }
    GlobalShortcut {
        name: "osdVolumeHide"
        description: qsTr("Hides volume OSD on press")

        onPressed: {
            root.showOsdValues = false
        }
    }

}
