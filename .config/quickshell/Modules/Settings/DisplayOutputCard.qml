// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Carbon contributors

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "root:/Modules/Common/"
import "root:/Modules/Common/Widgets/"

Rectangle {
    id: root

    required property var output
    property string selectedModeId: output.current_mode_id ?? ""
    property bool controlsEnabled: true
    signal modeSelected(string modeId)

    function modeLabel(mode): string {
        const hz = mode.refresh_mhz / 1000
        const refresh = Number.isInteger(hz)
            ? hz.toFixed(0)
            : hz.toFixed(3).replace(/0+$/, "").replace(/\.$/, "")
        return `${mode.width} × ${mode.height} · ${refresh} Hz${mode.preferred ? " · Preferred" : ""}`
    }

    function modeIndex(modeId: string): int {
        return root.output.modes.findIndex(mode => mode.id === modeId)
    }

    Layout.fillWidth: true
    implicitHeight: cardContent.implicitHeight + Appearance.spacing.lg * 2
    radius: Appearance.rounding.normal
    color: Appearance.m3colors.m3surfaceContainer
    border.width: 1
    border.color: Appearance.m3colors.m3outlineVariant

    ColumnLayout {
        id: cardContent
        anchors {
            fill: parent
            margins: Appearance.spacing.lg
        }
        spacing: Appearance.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            Rectangle {
                implicitWidth: 44
                implicitHeight: 44
                radius: Appearance.rounding.small
                color: Appearance.colors.colSecondaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "desktop_windows"
                    iconSize: 24
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: root.output.name
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                StyledText {
                    text: root.output.connector
                    color: Appearance.m3colors.m3outline
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }

            StyledText {
                text: root.output.enabled ? qsTr("Connected") : qsTr("Disabled")
                color: Appearance.m3colors.m3primary
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: {
                const current = root.output.modes.find(mode => mode.id === root.output.current_mode_id)
                return current ? qsTr("Current: %1").arg(root.modeLabel(current)) : qsTr("Current mode unavailable")
            }
            color: Appearance.m3colors.m3outline
        }

        ComboBox {
            id: modeSelector
            Layout.fillWidth: true
            implicitHeight: 44
            enabled: root.controlsEnabled && root.output.enabled
            model: root.output.modes.map(mode => ({
                id: mode.id,
                label: root.modeLabel(mode)
            }))
            textRole: "label"
            currentIndex: root.modeIndex(root.selectedModeId)
            onActivated: index => root.modeSelected(root.output.modes[index].id)

            background: Rectangle {
                radius: Appearance.rounding.small
                color: modeSelector.hovered
                    ? Appearance.colors.colSecondaryContainerHover
                    : Appearance.colors.colSecondaryContainer
                border.width: modeSelector.activeFocus ? 2 : 0
                border.color: Appearance.m3colors.m3primary
            }
            contentItem: StyledText {
                leftPadding: Appearance.spacing.md
                rightPadding: 40
                text: modeSelector.displayText
                color: Appearance.colors.colOnSecondaryContainer
                elide: Text.ElideRight
            }
            indicator: MaterialSymbol {
                x: modeSelector.width - width - Appearance.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                text: "expand_more"
                iconSize: 22
                color: Appearance.colors.colOnSecondaryContainer
                rotation: modeSelector.popup.visible ? 180 : 0
                Behavior on rotation {
                    NumberAnimation { duration: 120 }
                }
            }
            delegate: ItemDelegate {
                id: optionDelegate
                required property var modelData
                required property int index
                width: ListView.view?.width ?? modeSelector.width
                implicitHeight: 42
                highlighted: modeSelector.highlightedIndex === index
                contentItem: StyledText {
                    text: optionDelegate.modelData.label
                    color: Appearance.colors.colOnLayer2
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: Appearance.rounding.small
                    color: optionDelegate.highlighted
                        ? Appearance.colors.colLayer2Hover
                        : "transparent"
                }
            }
            popup: Popup {
                y: modeSelector.height + 4
                width: modeSelector.width
                height: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, 320)
                padding: Appearance.spacing.xs
                background: Rectangle {
                    radius: Appearance.rounding.normal
                    color: Appearance.m3colors.m3surfaceContainerHigh
                    border.width: 1
                    border.color: Appearance.m3colors.m3outlineVariant
                }
                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: modeSelector.popup.visible ? modeSelector.delegateModel : null
                    currentIndex: modeSelector.highlightedIndex
                }
            }
        }
    }
}
