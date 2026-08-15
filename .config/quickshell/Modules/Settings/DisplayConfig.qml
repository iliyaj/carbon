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
                    : qsTr("Nagame is optional. Carbon's static Hyprland display fallback is still active.")
                color: Appearance.m3colors.m3outline
                wrapMode: Text.Wrap
            }
            RippleButtonWithIcon {
                materialIcon: "refresh"
                mainText: qsTr("Retry")
                enabled: !NagameDisplay.loading
                onClicked: NagameDisplay.refresh()
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
}
