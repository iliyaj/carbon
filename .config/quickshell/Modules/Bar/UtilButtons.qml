import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

Item {
    id: root
    property bool borderless: ConfigOptions.bar.borderless
    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: rowLayout.implicitHeight

    RowLayout {
        id: rowLayout

        spacing: 4
        anchors.centerIn: parent

        Loader {
            active: ConfigOptions.bar.utilButtons.showScreenSnip
            visible: ConfigOptions.bar.utilButtons.showScreenSnip
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Hyprland.dispatch("hl.dsp.exec_cmd([[hyprshot --freeze --mode region --output-folder ~/Pictures/Screenshots]])")
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "screenshot_region"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: ConfigOptions.bar.utilButtons.showScreenSnipDelayed
            visible: ConfigOptions.bar.utilButtons.showScreenSnipDelayed
            sourceComponent: CircleUtilButton {
                id: delayedSnipButton
                property int countdown: 0
                Layout.alignment: Qt.AlignVCenter
                onClicked: {
                    if (delayedSnipButton.countdown > 0) return;
                    delayedSnipButton.countdown = 3;
                    countdownTimer.restart();
                    Hyprland.dispatch("hl.dsp.exec_cmd([[sleep 3 && hyprshot --freeze --mode region --output-folder ~/Pictures/Screenshots]])")
                }
                Item {
                    implicitWidth: snipIcon.implicitWidth
                    implicitHeight: snipIcon.implicitHeight

                    Timer {
                        id: countdownTimer
                        interval: 1000
                        repeat: true
                        onTriggered: {
                            delayedSnipButton.countdown -= 1;
                            if (delayedSnipButton.countdown <= 0) stop();
                        }
                    }
                    MaterialSymbol {
                        id: snipIcon
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 1
                        text: "timer"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer2
                        visible: delayedSnipButton.countdown === 0
                    }
                    StyledText {
                        anchors.centerIn: parent
                        visible: delayedSnipButton.countdown > 0
                        text: delayedSnipButton.countdown
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }
        }

        CircleUtilButton {
            Layout.alignment: Qt.AlignVCenter
            onClicked: Hyprland.dispatch("hl.dsp.exec_cmd([[dolphin]])")
            MaterialSymbol {
                horizontalAlignment: Qt.AlignHCenter
                fill: 0
                text: "folder_open"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer2
            }
        }

        Loader {
            active: ConfigOptions.bar.utilButtons.showColorPicker
            visible: ConfigOptions.bar.utilButtons.showColorPicker
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Hyprland.dispatch("hl.dsp.exec_cmd([[hyprpicker -a]])")
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "colorize"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: ConfigOptions.bar.utilButtons.showKeyboardToggle
            visible: ConfigOptions.bar.utilButtons.showKeyboardToggle
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Hyprland.dispatch("hl.dsp.global([[quickshell:oskToggle]])")
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: "keyboard"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: ConfigOptions.bar.utilButtons.showMicToggle
            visible: ConfigOptions.bar.utilButtons.showMicToggle
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Hyprland.dispatch("hl.dsp.exec_cmd([[wpctl set-mute @DEFAULT_SOURCE@ toggle]])")
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: Pipewire.defaultAudioSource?.audio?.muted ? "mic_off" : "mic"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: ConfigOptions.bar.utilButtons.showDarkModeToggle
            visible: ConfigOptions.bar.utilButtons.showDarkModeToggle
            sourceComponent: CircleUtilButton {
                id: darkToggleBtn
                property bool isDark: Appearance.m3colors.darkmode
                Layout.alignment: Qt.AlignVCenter
                onClicked: event => {
                    darkToggleBtn.isDark = !darkToggleBtn.isDark
                    Quickshell.execDetached([Directories.wallpaperToolPath, "--mode", darkToggleBtn.isDark ? "dark" : "light", "--noswitch"])
                }
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: darkToggleBtn.isDark ? "light_mode" : "dark_mode"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }
    }
}
