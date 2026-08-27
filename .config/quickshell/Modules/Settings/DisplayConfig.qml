// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Carbon contributors

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "root:/Services/"
import "root:/Modules/Common/"
import "root:/Modules/Common/Widgets/"

ContentPage {
    id: root

    property var selectedModes: ({})

    function resetSelections() {
        const next = ({})
        for (const output of NagameDisplay.outputs)
            next[output.connector] = output.current_mode_id ?? ""
        root.selectedModes = next
    }

    function selectMode(connector: string, modeId: string) {
        const next = ({})
        for (const output of NagameDisplay.outputs)
            next[output.connector] = output.current_mode_id ?? ""
        next[connector] = modeId
        root.selectedModes = next
    }

    Component.onCompleted: NagameDisplay.refresh()

    Connections {
        target: NagameDisplay
        function onOutputsChanged() { root.resetSelections() }
    }

    component ValueField: MaterialTextField {
        property string configKey: ""
        property string configValue: ""
        Layout.fillWidth: true
        text: configValue
        onConfigValueChanged: {
            if (!activeFocus)
                text = configValue
        }
        onActiveFocusChanged: {
            if (!activeFocus && text !== configValue)
                ConfigLoader.setConfigValueAndSave(configKey, text)
        }
    }

    forceWidth: true

    ContentSection {
        title: qsTr("Safe display preview")

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: previewContent.implicitHeight + Appearance.spacing.lg * 2
            radius: Appearance.rounding.normal
            color: NagameDisplay.previewActive
                ? Appearance.colors.colSecondaryContainer
                : Appearance.m3colors.m3surfaceContainer

            ColumnLayout {
                id: previewContent
                anchors {
                    fill: parent
                    margins: Appearance.spacing.lg
                }
                spacing: Appearance.spacing.md

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.md

                    MaterialSymbol {
                        text: NagameDisplay.previewActive ? "timer" : "shield"
                        iconSize: 28
                        color: NagameDisplay.previewActive
                            ? Appearance.colors.colOnSecondaryContainer
                            : Appearance.m3colors.m3primary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText {
                            Layout.fillWidth: true
                            text: NagameDisplay.previewActive
                                ? qsTr("Keep these display settings? · %1 seconds").arg(NagameDisplay.remainingSeconds)
                                : qsTr("Safe display changes")
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.Medium
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: NagameDisplay.previewActive
                                ? NagameDisplay.statusMessage
                                : qsTr("Nagame tests the complete configuration before previewing it. Unconfirmed changes revert automatically.")
                            color: Appearance.m3colors.m3outline
                            wrapMode: Text.Wrap
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    visible: NagameDisplay.previewActive
                    spacing: Appearance.spacing.sm

                    RippleButtonWithIcon {
                        materialIcon: "undo"
                        mainText: qsTr("Revert")
                        enabled: !NagameDisplay.confirming && !NagameDisplay.reverting
                        onClicked: NagameDisplay.revert()
                    }

                    RippleButtonWithIcon {
                        materialIcon: "check"
                        mainText: NagameDisplay.confirming ? qsTr("Saving…") : qsTr("Keep changes")
                        enabled: !NagameDisplay.confirming && !NagameDisplay.reverting
                        onClicked: NagameDisplay.confirm()
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: NagameDisplay.errorMessage.length > 0
                && NagameDisplay.errorCode !== "unconfigured"
                && NagameDisplay.errorCode !== "stopped"
                && NagameDisplay.errorCode !== "not_installed"
            text: NagameDisplay.errorMessage
            color: Appearance.m3colors.m3error
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            visible: NagameDisplay.loading || !NagameDisplay.available
            spacing: Appearance.spacing.sm
            BusyIndicator {
                visible: NagameDisplay.loading
                running: visible
                implicitWidth: 28
                implicitHeight: 28
            }
            StyledText {
                Layout.fillWidth: true
                text: NagameDisplay.loading
                    ? qsTr("Reading connected outputs from Nagame…")
                    : NagameDisplay.backendState === "unconfigured"
                        ? qsTr("Nagame is installed but not configured. Set it up from the displays connected now.")
                        : NagameDisplay.backendState === "stopped"
                            ? qsTr("Nagame is configured but not running.")
                            : NagameDisplay.backendState === "starting"
                                ? qsTr("Nagame is starting…")
                                : NagameDisplay.backendState === "not_installed"
                                    ? qsTr("Nagame is not installed. Carbon's static Hyprland display fallback is active.")
                                    : qsTr("Checking the Nagame service…")
                color: Appearance.m3colors.m3outline
                wrapMode: Text.Wrap
            }
            RippleButtonWithIcon {
                materialIcon: NagameDisplay.backendState === "unconfigured"
                    ? "settings_suggest"
                    : NagameDisplay.backendState === "stopped"
                        ? "play_arrow"
                        : "refresh"
                mainText: NagameDisplay.backendState === "unconfigured"
                    ? qsTr("Set up Nagame")
                    : NagameDisplay.backendState === "stopped"
                        ? qsTr("Start Nagame")
                        : qsTr("Retry")
                enabled: !NagameDisplay.loading && !NagameDisplay.setupRunning
                onClicked: {
                    if (NagameDisplay.backendState === "unconfigured")
                        NagameDisplay.setup()
                    else if (NagameDisplay.backendState === "stopped")
                        NagameDisplay.start()
                    else
                        NagameDisplay.refresh()
                }
            }
        }
    }

    ContentSection {
        visible: NagameDisplay.available
        title: qsTr("Connected displays")

        StyledText {
            Layout.fillWidth: true
            visible: !NagameDisplay.outputManagementSupported || NagameDisplay.outputs.length === 0
            text: NagameDisplay.outputManagementSupported
                ? qsTr("Nagame did not report any connected displays.")
                : qsTr("This compositor does not provide the output-management protocol Nagame needs.")
            color: Appearance.m3colors.m3outline
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: NagameDisplay.outputs.length > 0 && NagameDisplay.activeProfile.length === 0
            text: qsTr("No Nagame profile matches the connected displays. Choose or create a matching profile before applying changes.")
            color: Appearance.m3colors.m3error
            wrapMode: Text.Wrap
        }

        Repeater {
            visible: NagameDisplay.outputManagementSupported
            model: NagameDisplay.outputs
            delegate: DisplayOutputCard {
                id: outputCard
                required property var modelData
                output: modelData
                selectedModeId: root.selectedModes[modelData.connector] ?? modelData.current_mode_id ?? ""
                controlsEnabled: !NagameDisplay.previewActive
                onModeSelected: modeId => root.selectMode(modelData.connector, modeId)
            }
        }

        RippleButtonWithIcon {
            Layout.alignment: Qt.AlignRight
            materialIcon: "preview"
            mainText: qsTr("Apply")
            enabled: {
                if (NagameDisplay.previewActive || NagameDisplay.loading || !NagameDisplay.outputManagementSupported)
                    return false
                if (NagameDisplay.activeProfile.length === 0 || NagameDisplay.configRevision.length === 0)
                    return false
                return NagameDisplay.outputs.some(output => {
                    const selected = root.selectedModes[output.connector]
                    return output.enabled
                        && selected
                        && selected !== output.current_mode_id
                        && output.modes.some(mode => mode.id === selected)
                })
            }
            onClicked: {
                const output = NagameDisplay.outputs.find(candidate => {
                    const selected = root.selectedModes[candidate.connector]
                    return candidate.enabled
                        && selected
                        && selected !== candidate.current_mode_id
                        && candidate.modes.some(mode => mode.id === selected)
                })
                if (output)
                    NagameDisplay.preview(output.connector, root.selectedModes[output.connector])
            }
        }
    }

    ContentSection {
        title: qsTr("Night light")

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            MaterialSymbol {
                text: "nightlight"
                iconSize: 28
                color: NightLight.enabled ? Appearance.m3colors.m3primary : Appearance.m3colors.m3outline
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: NightLight.statusText
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    text: NightLight.scheduleText
                    font.italic: true
                    color: Appearance.m3colors.m3outline
                    wrapMode: Text.Wrap
                }
            }

            RippleButtonWithIcon {
                materialIcon: NightLight.enabled ? "bedtime_off" : "nightlight"
                mainText: NightLight.enabled ? qsTr("Turn off") : qsTr("Turn on")
                enabled: NightLight.available
                onClicked: NightLight.toggle()
            }
        }

        ContentSubsection {
            title: qsTr("Temperature")

            ConfigSpinBox {
                text: qsTr("Daytime (K)")
                value: ConfigOptions.nightLight.dayTemperature
                from: 2000
                to: 6500
                stepSize: 100
                onValueChanged: ConfigLoader.setConfigValueAndSave("nightLight.dayTemperature", value)
            }
            ConfigSpinBox {
                text: qsTr("Night (K)")
                value: ConfigOptions.nightLight.nightTemperature
                from: 2000
                to: 6500
                stepSize: 100
                onValueChanged: ConfigLoader.setConfigValueAndSave("nightLight.nightTemperature", value)
            }
        }

        ContentSubsection {
            title: qsTr("Schedule")
            tooltip: qsTr("Without custom times, night light follows the sun's elevation at your location.")

            ConfigSwitch {
                text: qsTr("Use custom times")
                checked: ConfigOptions.nightLight.manualSchedule
                onCheckedChanged: ConfigLoader.setConfigValueAndSave("nightLight.manualSchedule", checked)
            }
            ConfigRow {
                uniform: true
                visible: ConfigOptions.nightLight.manualSchedule
                ValueField {
                    placeholderText: qsTr("Sunrise (HH:MM)")
                    configKey: "nightLight.sunriseTime"
                    configValue: ConfigOptions.nightLight.sunriseTime
                }
                ValueField {
                    placeholderText: qsTr("Sunset (HH:MM)")
                    configKey: "nightLight.sunsetTime"
                    configValue: ConfigOptions.nightLight.sunsetTime
                }
            }
            ConfigSpinBox {
                visible: ConfigOptions.nightLight.manualSchedule
                text: qsTr("Fade duration (minutes)")
                value: ConfigOptions.nightLight.transitionMinutes
                from: 1
                to: 240
                stepSize: 5
                onValueChanged: ConfigLoader.setConfigValueAndSave("nightLight.transitionMinutes", value)
            }
        }

        ContentSubsection {
            title: qsTr("Location")
            visible: !ConfigOptions.nightLight.manualSchedule

            ConfigRow {
                uniform: true
                ValueField {
                    placeholderText: qsTr("Latitude")
                    configKey: "nightLight.latitude"
                    configValue: String(ConfigOptions.nightLight.latitude)
                }
                ValueField {
                    placeholderText: qsTr("Longitude")
                    configKey: "nightLight.longitude"
                    configValue: String(ConfigOptions.nightLight.longitude)
                }
            }
            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                text: qsTr("Sunset schedule computed for %1").arg(NightLight.coordinatesText)
                font.italic: true
                color: Appearance.colors.colOnLayer1Inactive
                wrapMode: Text.Wrap
            }
        }
    }
}
