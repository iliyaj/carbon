import qs.Modules.Common
import qs.Modules.Common.Widgets
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: recoveryWindow

            required property var modelData

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            mask: Region { item: recoveryButton }

            WlrLayershell.namespace: "quickshell:barSettingsRecovery"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            RippleButton {
                id: recoveryButton

                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: Appearance.spacing.sm
                    bottomMargin: Appearance.spacing.sm
                }
                width: 40
                height: 40
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active

                onClicked: Quickshell.execDetached([
                    "qs", "-p", Quickshell.shellPath("settings.qml")
                ])

                contentItem: Item {
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "settings"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer0
                        opacity: recoveryButton.hovered ? 0.9 : 0.5

                        Behavior on opacity {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }
                }

                StyledToolTip {
                    x: recoveryButton.width - implicitWidth
                    y: -implicitHeight - Appearance.spacing.xs
                    content: qsTr("Open Carbon Settings")
                }

            }
        }
    }
}
