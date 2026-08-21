import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "root:/Services/"
import "root:/Modules/Common/"
import "root:/Modules/Common/Widgets/"

ContentPage {
    forceWidth: true

    ContentSection {
        title: "Desktop"

        ConfigRow {
            ConfigSwitch {
                text: "Clock and date"
                checked: ConfigOptions.background.showClock
                onCheckedChanged: {
                    ConfigLoader.setConfigValueAndSave("background.showClock", checked);
                }
            }
        }
    }

    ContentSection {
        title: "Bar"

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
            title: "Buttons"
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: "Screen snip"
                    checked: ConfigOptions.bar.utilButtons.showScreenSnip
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("bar.utilButtons.showScreenSnip", checked);
                    }
                }
                ConfigSwitch {
                    text: "Color picker"
                    checked: ConfigOptions.bar.utilButtons.showColorPicker
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("bar.utilButtons.showColorPicker", checked);
                    }
                }
            }
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: "Mic toggle"
                    checked: ConfigOptions.bar.utilButtons.showMicToggle
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("bar.utilButtons.showMicToggle", checked);
                    }
                }
                ConfigSwitch {
                    text: "Keyboard toggle"
                    checked: ConfigOptions.bar.utilButtons.showKeyboardToggle
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("bar.utilButtons.showKeyboardToggle", checked);
                    }
                }
            }
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: "Dark/Light toggle"
                    checked: ConfigOptions.bar.utilButtons.showDarkModeToggle
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("bar.utilButtons.showDarkModeToggle", checked);
                    }
                }
                ConfigSwitch {
                    text: "Screen snip (delayed)"
                    checked: ConfigOptions.bar.utilButtons.showScreenSnipDelayed
                    onCheckedChanged: {
                        ConfigLoader.setConfigValueAndSave("bar.utilButtons.showScreenSnipDelayed", checked);
                    }
                    StyledToolTip {
                        content: "Adds a button that waits 3 seconds before opening the region picker"
                    }
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
}
