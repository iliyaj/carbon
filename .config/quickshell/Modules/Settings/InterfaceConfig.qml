import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Services
import qs.Modules.Common
import qs.Modules.Common.Widgets

ContentPage {
    forceWidth: true

    component BarItemSwitch: ConfigSwitch {
        id: barItemSwitch

        required property string settingKey
        required property string description

        onCheckedChanged: ConfigLoader.setConfigValueAndSave(settingKey, checked)

        StyledToolTip {
            content: barItemSwitch.description
        }
    }

    ContentSection {
        title: "Desktop"

        ConfigRow {
            uniform: true
            ConfigSwitch {
                text: "Clock and date"
                checked: ConfigOptions.background.showClock
                onCheckedChanged: {
                    ConfigLoader.setConfigValueAndSave("background.showClock", checked);
                }
                StyledToolTip {
                    content: "Shows the clock and date on the wallpaper."
                }
            }
            ConfigSwitch {
                text: "Hide clock in fullscreen"
                enabled: ConfigOptions.background.showClock
                checked: ConfigOptions.background.hideWhenFullscreen
                onCheckedChanged: {
                    ConfigLoader.setConfigValueAndSave("background.hideWhenFullscreen", checked);
                }
                StyledToolTip {
                    content: "Hides the wallpaper clock when an app is fullscreen."
                }
            }
        }
    }

    ContentSection {
        title: "Bar"

        ContentSubsection {
            title: "Visibility"
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: "Top bar"
                    checked: ConfigOptions.bar.enable
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("bar.enable", checked);
                    }
                    StyledToolTip {
                        content: "Shows the top bar and reserves its edge space. Turning it off lets windows use the full screen."
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }

        ContentSubsection {
            title: "Appearance"
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: 'Borderless'
                    checked: ConfigOptions.bar.borderless
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("bar.borderless", checked);
                    }
                }
                ConfigSwitch {
                    text: 'Show background'
                    checked: ConfigOptions.bar.showBackground
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("bar.showBackground", checked);
                    }
                    StyledToolTip {
                        content: "Note: turning off can hurt readability"
                    }
                }
            }
        }

        ContentSubsection {
            title: "Contents"
            tooltip: "If the bar or both navigation buttons are off, a recovery settings button appears in the bottom-right corner."
            GridLayout {
                columns: 2
                columnSpacing: Appearance.spacing.md
                rowSpacing: 0
                uniformCellWidths: true

                BarItemSwitch {
                    text: "App drawer button"
                    settingKey: "bar.modules.showLeftSidebarButton"
                    description: "Opens the app drawer and left sidebar."
                    checked: ConfigOptions.bar.modules.showLeftSidebarButton
                }
                BarItemSwitch {
                    text: "Quick settings button"
                    settingKey: "bar.modules.showRightSidebarButton"
                    description: "Opens notifications, calendar, volume mixer, and quick settings."
                    checked: ConfigOptions.bar.modules.showRightSidebarButton
                }
                BarItemSwitch {
                    text: "Active window"
                    settingKey: "bar.modules.showActiveWindow"
                    description: "Shows the icon and title of the focused application."
                    checked: ConfigOptions.bar.modules.showActiveWindow
                }
                BarItemSwitch {
                    text: "Minimized windows"
                    settingKey: "bar.modules.showMinimizedWindows"
                    description: "Shows restorable icons for Carbon-minimized windows."
                    checked: ConfigOptions.bar.modules.showMinimizedWindows
                }
                BarItemSwitch {
                    text: "RAM usage"
                    settingKey: "bar.modules.showResources"
                    description: "Shows current memory usage."
                    checked: ConfigOptions.bar.modules.showResources
                }
                BarItemSwitch {
                    text: "Media"
                    settingKey: "bar.modules.showMedia"
                    description: "Shows the current player and opens media controls."
                    checked: ConfigOptions.bar.modules.showMedia
                }
                BarItemSwitch {
                    text: "Workspaces"
                    settingKey: "bar.modules.showWorkspaces"
                    description: "Shows workspace status and navigation."
                    checked: ConfigOptions.bar.modules.showWorkspaces
                }
                BarItemSwitch {
                    text: "Clock and date"
                    settingKey: "bar.showClock"
                    description: "Shows the current time and, when space allows, the date."
                    checked: ConfigOptions.bar.showClock
                }
                BarItemSwitch {
                    text: "Battery"
                    settingKey: "bar.modules.showBattery"
                    description: "Shows charge status when a laptop battery is available."
                    checked: ConfigOptions.bar.modules.showBattery
                }
                BarItemSwitch {
                    text: "System tray"
                    settingKey: "bar.modules.showSystemTray"
                    description: "Shows status icons supplied by background applications."
                    checked: ConfigOptions.bar.modules.showSystemTray
                }
            }
        }

        ContentSubsection {
            title: "Utility buttons"
            GridLayout {
                columns: 2
                columnSpacing: Appearance.spacing.md
                rowSpacing: 0
                uniformCellWidths: true

                BarItemSwitch {
                    text: "Screen snip"
                    settingKey: "bar.utilButtons.showScreenSnip"
                    description: "Opens the region screenshot picker."
                    checked: ConfigOptions.bar.utilButtons.showScreenSnip
                }
                BarItemSwitch {
                    text: "Screen snip (delayed)"
                    settingKey: "bar.utilButtons.showScreenSnipDelayed"
                    description: "Waits three seconds before opening the region screenshot picker."
                    checked: ConfigOptions.bar.utilButtons.showScreenSnipDelayed
                }
                BarItemSwitch {
                    text: "Clipboard"
                    settingKey: "bar.utilButtons.showClipboard"
                    description: "Opens clipboard history in the overview."
                    checked: ConfigOptions.bar.utilButtons.showClipboard
                }
                BarItemSwitch {
                    text: "Mic toggle"
                    settingKey: "bar.utilButtons.showMicToggle"
                    description: "Mutes or unmutes the default microphone."
                    checked: ConfigOptions.bar.utilButtons.showMicToggle
                }
                BarItemSwitch {
                    text: "Keyboard toggle"
                    settingKey: "bar.utilButtons.showKeyboardToggle"
                    description: "Shows or hides the on-screen keyboard."
                    checked: ConfigOptions.bar.utilButtons.showKeyboardToggle
                }
                BarItemSwitch {
                    text: "Dark/Light toggle"
                    settingKey: "bar.utilButtons.showDarkModeToggle"
                    description: "Switches the generated theme between dark and light modes."
                    checked: ConfigOptions.bar.utilButtons.showDarkModeToggle
                }
                BarItemSwitch {
                    text: "Color picker"
                    settingKey: "bar.utilButtons.showColorPicker"
                    description: "Picks a screen color and copies it to the clipboard."
                    checked: ConfigOptions.bar.utilButtons.showColorPicker
                }
                BarItemSwitch {
                    text: "File manager"
                    settingKey: "bar.utilButtons.showFileManager"
                    description: "Opens Dolphin."
                    checked: ConfigOptions.bar.utilButtons.showFileManager
                }
            }
        }

        ContentSubsection {
            title: "Workspaces"
            tooltip: "Tip: Hide icons and always show numbers for\nCarbon's compact workspace style"

            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: 'Show app icons'
                    checked: ConfigOptions.bar.workspaces.showAppIcons
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("bar.workspaces.showAppIcons", checked);
                    }
                }
                ConfigSwitch {
                    text: 'Always show numbers'
                    checked: ConfigOptions.bar.workspaces.alwaysShowNumbers
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("bar.workspaces.alwaysShowNumbers", checked);
                    }
                }
            }
            ConfigSpinBox {
                text: "Workspaces shown"
                value: ConfigOptions.bar.workspaces.shown
                from: 1
                to: 30
                stepSize: 1
                onValueChanged: {
                    ConfigLoader.setConfigValueAndSave("bar.workspaces.shown", value);
                }
            }
            ConfigSpinBox {
                text: "Number show delay when pressing Super (ms)"
                value: ConfigOptions.bar.workspaces.showNumberDelay
                from: 0
                to: 1000
                stepSize: 50
                onValueChanged: {
                    ConfigLoader.setConfigValueAndSave("bar.workspaces.showNumberDelay", value);
                }
            }
        }
    }

    ContentSection {
        title: "Dock"

        ConfigRow {
            uniform: true
            ConfigSwitch {
                text: "Dock"
                checked: ConfigOptions.dock.enable
                onCheckedChanged: {
                    ConfigLoader.setConfigValueAndSave("dock.enable", checked);
                }
                StyledToolTip {
                    content: "Shows a dock along the bottom edge with pinned and running applications."
                }
            }
            ConfigSwitch {
                text: "Automatically hide"
                enabled: ConfigOptions.dock.enable
                checked: !ConfigOptions.dock.pinnedOnStartup
                onCheckedChanged: {
                    ConfigLoader.setConfigValueAndSave("dock.pinnedOnStartup", !checked);
                    ConfigLoader.setConfigValueAndSave("dock.hoverToReveal", checked);
                }
                StyledToolTip {
                    content: "Keeps the dock off screen until the pointer reaches the bottom edge, instead of always showing it."
                }
            }
        }
    }

    ContentSection {
        title: "Clipboard"

        RippleButtonWithIcon {
            materialIcon: "delete_sweep"
            mainText: "Clear clipboard history"
            onClicked: Quickshell.execDetached([
                "bash",
                "-c",
                "cliphist wipe && wl-copy --clear && notify-send -a Carbon 'Clipboard cleared' 'Clipboard contents and history were removed'"
            ])
            StyledToolTip {
                content: "Permanently removes the current clipboard contents and all saved entries"
            }
        }
    }

    ContentSection {
        title: "Battery"

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                text: "Low warning"
                value: ConfigOptions.battery.low
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    ConfigLoader.setConfigValueAndSave("battery.low", value);
                }
            }
            ConfigSpinBox {
                text: "Critical warning"
                value: ConfigOptions.battery.critical
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    ConfigLoader.setConfigValueAndSave("battery.critical", value);
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                text: "Automatic suspend"
                checked: ConfigOptions.battery.automaticSuspend
                onCheckedChanged: {
                    ConfigLoader.setConfigValueAndSave("battery.automaticSuspend", checked);
                }
                StyledToolTip {
                    content: "Automatically suspends the system when battery is low"
                }
            }
            ConfigSpinBox {
                text: "Suspend at"
                value: ConfigOptions.battery.suspend
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    ConfigLoader.setConfigValueAndSave("battery.suspend", value);
                }
            }
        }
    }

    ContentSection {
        title: "Auto-lock"

        ConfigRow {
            ColumnLayout {
                ContentSubsectionLabel {
                    text: "Lock timeout"
                }
                ConfigSelectionArray {
                    currentValue: ConfigOptions.autolock.timeout
                    configOptionName: "autolock.timeout"
                    onSelected: (newValue) => {
                        ConfigLoader.setConfigValueAndSave("autolock.timeout", newValue);
                    }
                    options: [
                        { displayName: "1 minute", value: 60 },
                        { displayName: "2 minutes", value: 120 },
                        { displayName: "5 minutes", value: 300 },
                        { displayName: "10 minutes", value: 600 },
                        { displayName: "15 minutes", value: 900 },
                        { displayName: "30 minutes", value: 1800 },
                        { displayName: "Never", value: -1 }
                    ]
                }
            }
        }
    }

    ContentSection {
        title: "Overview"
        ConfigSpinBox {
            text: "Scale (%)"
            value: ConfigOptions.overview.scale * 100
            from: 1
            to: 100
            stepSize: 1
            onValueChanged: {
                ConfigLoader.setConfigValueAndSave("overview.scale", value / 100);
            }
        }
        ConfigRow {
            uniform: true
            ConfigSpinBox {
                text: "Rows"
                value: ConfigOptions.overview.rows
                from: 1
                to: 20
                stepSize: 1
                onValueChanged: {
                    ConfigLoader.setConfigValueAndSave("overview.rows", value);
                }
            }
            ConfigSpinBox {
                text: "Columns"
                value: ConfigOptions.overview.columns
                from: 1
                to: 20
                stepSize: 1
                onValueChanged: {
                    ConfigLoader.setConfigValueAndSave("overview.columns", value);
                }
            }
        }

    }

    ContentSection {
        title: "Accessibility"

        ConfigRow {
            ConfigSwitch {
                text: "Show mouse clicks"
                checked: ConfigOptions.accessibility.showMouseClicks
                onCheckedChanged: {
                    ConfigLoader.setConfigValueAndSave("accessibility.showMouseClicks", checked);
                }
                StyledToolTip {
                    content: "Shows a brief pointer ripple for demonstrations and recordings"
                }
            }
        }
    }
}
