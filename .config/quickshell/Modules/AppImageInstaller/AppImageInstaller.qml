import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

Scope {
    id: root

    property string pendingAppName: ""
    property string pendingIconPath: ""
    property string pendingAppimagePath: ""

    function show(name, icon, path) {
        pendingAppName = name
        pendingIconPath = icon
        pendingAppimagePath = path
        overlayLoader.active = true
    }

    function hide() {
        overlayLoader.active = false
    }

    Process {
        id: installProcess
    }

    property bool ipcTriggered: false

    FileView {
        id: pendingFile
        path: "/tmp/appimage-pending.json"
        onLoaded: {
            if (!root.ipcTriggered) return
            root.ipcTriggered = false
            try {
                const msg = JSON.parse(pendingFile.text())
                root.show(msg.app_name, msg.icon_path, msg.appimage_path)
            } catch(e) {}
        }
    }

    IpcHandler {
        target: "appimage-installer"
        function trigger(): void {
            root.ipcTriggered = true
            pendingFile.reload()
        }
    }

    Loader {
        id: overlayLoader
        active: false

        sourceComponent: PanelWindow {
            id: win

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }

            // Backdrop — z:0, dismiss on click
            Rectangle {
                z: 0
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.6)
                opacity: card.opacity

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.hide()
                }
            }

            // Install card — z:1, sits above backdrop
            Rectangle {
                id: card
                z: 1
                anchors.centerIn: parent
                width: 580
                height: 260
                radius: 20
                color: Qt.rgba(0.12, 0.12, 0.14, 0.95)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                Component.onCompleted: { opacity = 0; opacity = 1 }

                // Eat clicks on the card so they don't reach the backdrop
                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Text {
                    id: titleText
                    z: 2
                    text: root.pendingAppName
                    color: "white"
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 28
                }

                Text {
                    z: 2
                    text: "Drag to install"
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: 13
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: titleText.bottom
                    anchors.topMargin: 4
                }

                // Draggable app icon
                Rectangle {
                    id: appIcon
                    z: 3
                    x: 80
                    y: 90
                    width: 96
                    height: 96
                    radius: 22
                    color: Qt.rgba(1, 1, 1, 0.06)

                    property real dragStartX: 80

                    Image {
                        anchors.fill: parent
                        anchors.margins: 8
                        source: root.pendingIconPath !== "" ? ("file://" + root.pendingIconPath) : ""
                        fillMode: Image.PreserveAspectFit
                    }

                    DragHandler {
                        target: null
                        yAxis.enabled: false
                        onActiveChanged: {
                            if (active) {
                                appIcon.dragStartX = appIcon.x
                            } else {
                                if (appIcon.x > 300)
                                    installAnimation.start()
                                else
                                    returnAnimation.start()
                            }
                        }
                        onTranslationChanged: {
                            appIcon.x = Math.max(80, Math.min(380, appIcon.dragStartX + translation.x))
                        }
                    }

                    NumberAnimation {
                        id: returnAnimation
                        target: appIcon; property: "x"; to: 80
                        duration: 300; easing.type: Easing.OutBounce
                    }

                    SequentialAnimation {
                        id: installAnimation
                        NumberAnimation {
                            target: appIcon; property: "x"; to: 380
                            duration: 180; easing.type: Easing.OutCubic
                        }
                        ScriptAction {
                            script: {
                                installProcess.command = [
                                    Quickshell.env("HOME") + "/.config/appimage-installer/install.sh",
                                    root.pendingAppimagePath,
                                    root.pendingAppName,
                                    root.pendingIconPath
                                ]
                                installProcess.running = true
                                root.hide()
                            }
                        }
                    }
                }

                // Animated chevron arrows
                Row {
                    z: 2
                    anchors.centerIn: parent
                    spacing: 6
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 8; height: 2; radius: 1
                            color: Qt.rgba(1, 1, 1, 0.2 + index * 0.2)
                            SequentialAnimation on opacity {
                                running: true; loops: Animation.Infinite
                                NumberAnimation { to: 0.2; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }
                        }
                    }
                }

                // Drop target
                Rectangle {
                    z: 2
                    x: 404; y: 90
                    width: 96; height: 96
                    radius: 22
                    color: appIcon.x > 300 ? Qt.rgba(0.2, 0.6, 1.0, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 12
                        source: "image://icon/inode-directory"
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        text: "~/.local/bin"
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.pixelSize: 11
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 8
                    }
                }

            }
        }
    }
}
