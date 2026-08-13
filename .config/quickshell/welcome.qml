//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import "root:/Services/"
import "root:/Modules/Common/"
import "root:/Modules/Common/Widgets/"
import "root:/Modules/Common/Functions/color_utils.js" as ColorUtils
import "root:/Modules/Common/Functions/file_utils.js" as FileUtils
import "root:/Modules/Common/Functions/string_utils.js" as StringUtils

ApplicationWindow {
    id: root
    property string firstRunFilePath: FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: 8
    property bool showNextTime: false
    visible: true
    onClosing: Qt.quit()
    title: "illogical-impulse Welcome"

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        ConfigLoader.loadConfig()
    }

    minimumWidth: 600
    minimumHeight: 400
    width: 800
    height: 650
    color: Appearance.m3colors.m3background

    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }

        Item { // Titlebar
            visible: ConfigOptions?.windows.showTitlebar
            Layout.fillWidth: true
            implicitHeight: Math.max(welcomeText.implicitHeight, windowControlsRow.implicitHeight)
            StyledText {
                id: welcomeText
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                }
                states: State {
                    name: "leftAligned"
                    when: !ConfigOptions.windows.centerTitle
                    AnchorChanges {
                        target: welcomeText
                        anchors.left: welcomeText.parent.left
                        anchors.horizontalCenter: undefined
                    }
                }
                color: Appearance.colors.colOnLayer0
                text: "Yooooo hi there"
                font.pixelSize: Appearance.font.pixelSize.title
                font.family: Appearance.font.family.title
            }
            RowLayout { // Window controls row
                id: windowControlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    text: "Show next time"
                }
                StyledSwitch {
                    id: showNextTimeSwitch
                    checked: root.showNextTime
                    scale: 0.6
                    Layout.alignment: Qt.AlignVCenter
                    onCheckedChanged: {
                        if (checked) {
                            Quickshell.execDetached(["rm", root.firstRunFilePath])
                        } else {
                            Quickshell.execDetached(["bash", "-c", `echo '${StringUtils.shellSingleQuoteEscape(root.firstRunFileContent)}' > '${StringUtils.shellSingleQuoteEscape(root.firstRunFilePath)}'`])
                        }
                    }
                }
                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 35
                    implicitHeight: 35
                    onClicked: root.close()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: 20
                    }
                }
            }
        }
        Rectangle { // Content container
            color: Appearance.m3colors.m3surfaceContainerLow
            radius: Appearance.rounding.windowRounding - root.contentPadding
            implicitHeight: contentColumn.implicitHeight
            implicitWidth: contentColumn.implicitWidth
            Layout.fillWidth: true
            Layout.fillHeight: true


            ContentPage {
                id: contentColumn
                anchors.fill: parent
                ContentSection {
                    title: "Style & wallpaper"

                    ButtonGroup {
                        Layout.fillWidth: true
                        LightDarkPreferenceButton {
                            dark: false
                        }
                        LightDarkPreferenceButton {
                            dark: true
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        RippleButtonWithIcon {
                            materialIcon: "wallpaper"
                            StyledToolTip {
                                content: "Pick wallpaper image on your system"
                            }
                            onClicked: {
                                Quickshell.execDetached([Directories.wallpaperToolPath])
                            }
                            mainContentComponent: Component {
                                RowLayout {
                                    spacing: 10
                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        text: "Choose file"
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                    RowLayout {
                                        spacing: 3
                                        KeyboardKey {
                                            key: "Ctrl"
                                        }
                                        KeyboardKey {
                                            key: "󰖳"
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: "+"
                                        }
                                        KeyboardKey {
                                            key: "T"
                                        }
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Change any time later with /dark, /light, /img in the launcher"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                ContentSection {
                    title: "Info"

                    Flow {
                        Layout.fillWidth: true
                        spacing: 5

                        RippleButtonWithIcon {
                            materialIcon: "keyboard_alt"
                            onClicked: {
                                Hyprland.dispatch("hl.dsp.global([[quickshell:cheatsheetOpen]])")
                            }
                            mainContentComponent: Component {
                                RowLayout {
                                    spacing: 10
                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        text: "Keybinds"
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                    RowLayout {
                                        spacing: 3
                                        KeyboardKey {
                                            key: "󰖳"
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: "+"
                                        }
                                        KeyboardKey {
                                            key: "/"
                                        }
                                    }
                                }
                            }
                        }

                        RippleButtonWithIcon {
                            materialIcon: "help"
                            mainText: "Usage"
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/iliyaj/carbon/blob/main/README.md")
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "construction"
                            mainText: "Configuration"
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/iliyaj/carbon/blob/main/INSTALL.md")
                            }
                        }
                    }
                }

                ContentSection {
                    title: "Useless buttons"

                    Flow {
                        Layout.fillWidth: true
                        spacing: 5

                        RippleButtonWithIcon {
                            nerdIcon: "󰊤"
                            mainText: "GitHub"
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/iliyaj/carbon")
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "fork_right"
                            mainText: "Upstream"
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/end-4/dots-hyprland")
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
