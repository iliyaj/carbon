import "root:/Services"
import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import "root:/Modules/Common/Functions/lua_utils.js" as LuaUtils
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

Item {
    id: root

    required property var bar

    readonly property var minimizedWindows: HyprlandData.windowList.filter(window =>
        window.workspace?.name === "special:special"
    )
    readonly property var monitorData: HyprlandData.monitors.find(monitor =>
        monitor.name === bar.screen.name
    )

    implicitWidth: rowLayout.implicitWidth
    height: parent.height
    visible: minimizedWindows.length > 0

    function restoreWindow(windowData) {
        const workspaceId = monitorData?.activeWorkspace?.id
        if (!windowData?.address || workspaceId === undefined)
            return

        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${workspaceId}, follow = false, window = ${LuaUtils.stringLiteral(`address:${windowData.address}`)} })`)
        Hyprland.dispatch(`hl.dsp.focus({ window = ${LuaUtils.stringLiteral(`address:${windowData.address}`)} })`)
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: 10

        Repeater {
            model: root.minimizedWindows

            MouseArea {
                id: minimizedWindowButton

                required property var modelData

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Appearance.font.pixelSize.larger
                implicitHeight: implicitWidth
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton

                onClicked: event => {
                    root.restoreWindow(modelData)
                    event.accepted = true
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: width / 2
                    color: Appearance.colors.colLayer1Hover
                    opacity: minimizedWindowButton.containsMouse ? 1 : 0

                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Appearance.font.pixelSize.larger
                    source: Quickshell.iconPath(
                        AppSearch.guessIcon(minimizedWindowButton.modelData.class),
                        "image-missing"
                    )
                }

            }
        }
    }
}
