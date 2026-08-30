import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import "root:/Services/"
import "root:/Modules/Common/"
import "root:/Modules/Common/Widgets/"
import "root:/Modules/Common/Functions"

ContentPage {
    baseWidth: 550
    forceWidth: true

    ContentSection {
        title: "Colors & Wallpaper"

        ButtonGroup {
            id: lightDarkButtonGroup
            property bool prefersDark: Appearance.m3colors.darkmode
            Layout.fillWidth: true
            LightDarkPreferenceButton {
                dark: false
                toggled: !lightDarkButtonGroup.prefersDark
                onClicked: {
                    lightDarkButtonGroup.prefersDark = false
                    Quickshell.execDetached([Directories.wallpaperToolPath, "--mode", "light", "--noswitch"])
                }
            }
            LightDarkPreferenceButton {
                dark: true
                toggled: lightDarkButtonGroup.prefersDark
                onClicked: {
                    lightDarkButtonGroup.prefersDark = true
                    Quickshell.execDetached([Directories.wallpaperToolPath, "--mode", "dark", "--noswitch"])
                }
            }
        }

        ContentSubsection {
            title: "Material palette"
            ConfigSelectionArray {
                currentValue: ConfigOptions.appearance.palette.type
                configOptionName: "appearance.palette.type"
                onSelected: (newValue) => {
                    ConfigLoader.setConfigValueAndSave("appearance.palette.type", newValue);
                    Quickshell.execDetached([Directories.wallpaperToolPath, "--noswitch", "--type", newValue]);
                }
                options: [
                    {"value": "auto", "displayName": "Auto"},
                    {"value": "scheme-content", "displayName": "Content"},
                    {"value": "scheme-expressive", "displayName": "Expressive"},
                    {"value": "scheme-fidelity", "displayName": "Fidelity"},
                    {"value": "scheme-fruit-salad", "displayName": "Fruit Salad"},
                    {"value": "scheme-monochrome", "displayName": "Monochrome"},
                    {"value": "scheme-neutral", "displayName": "Neutral"},
                    {"value": "scheme-rainbow", "displayName": "Rainbow"},
                    {"value": "scheme-tonal-spot", "displayName": "Tonal Spot"}
                ]
            }
        }
        ContentSubsection {
            title: "Desktop Wallpaper"
            RowLayout {
                Layout.fillWidth: true
                RippleButtonWithIcon {
                    materialIcon: "wallpaper"
                    StyledToolTip {
                        content: "Pick wallpaper image on your system"
                    }
                    onClicked: {
                        Quickshell.execDetached([Directories.wallpaperToolPath])
                    }
                    mainContentComponent: Component {
                        StyledText {
                            font.pixelSize: Appearance.font.pixelSize.small
                            text: "Choose file"
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }
            }
        }

    }

    ContentSection {
        title: "Decorations & Effects"

        ContentSubsection {
            title: "Transparency"

            ConfigRow {
                ConfigSwitch {
                    text: "Enable"
                    checked: ConfigOptions.appearance.transparency
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("appearance.transparency", checked);
                    }
                    StyledToolTip {
                        content: "Might look ass. Unsupported."
                    }
                }
            }
        }

        ContentSubsection {
            title: "Resource pill colors"

            ConfigRow {
                ConfigSwitch {
                    text: "Match theme"
                    checked: ConfigOptions.appearance.themedResourceColors
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("appearance.themedResourceColors", checked);
                    }
                    StyledToolTip {
                        content: "Color the RAM pill from the generated palette instead of the fixed green, white, yellow and red."
                    }
                }
            }
        }

        ContentSubsection {
            title: "Fake screen rounding"

            ButtonGroup {
                id: fakeScreenRoundingButtonGroup
                property int selectedPolicy: ConfigOptions.appearance.fakeScreenRounding
                spacing: Appearance.spacing.xs
                SelectionGroupButton {
                    property int value: 0
                    leftmost: true
                    buttonText: "No"
                    toggled: (fakeScreenRoundingButtonGroup.selectedPolicy === value)
                    onClicked: {
                        ConfigLoader.setConfigValueAndSave("appearance.fakeScreenRounding", value);
                    }
                }
                SelectionGroupButton {
                    property int value: 1
                    buttonText: "Yes"
                    toggled: (fakeScreenRoundingButtonGroup.selectedPolicy === value)
                    onClicked: {
                        ConfigLoader.setConfigValueAndSave("appearance.fakeScreenRounding", value);
                    }
                }
                SelectionGroupButton {
                    property int value: 2
                    rightmost: true
                    buttonText: "When not fullscreen"
                    toggled: (fakeScreenRoundingButtonGroup.selectedPolicy === value)
                    onClicked: {
                        ConfigLoader.setConfigValueAndSave("appearance.fakeScreenRounding", value);
                    }
                }
            }
        }

        ContentSubsection {
            title: "Shell windows"

            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: "Title bar"
                    checked: ConfigOptions.windows.showTitlebar
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("windows.showTitlebar", checked);
                    }
                }
                ConfigSwitch {
                    text: "Center title"
                    checked: ConfigOptions.windows.centerTitle
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("windows.centerTitle", checked);
                    }
                }
            }
        }
    }
}
