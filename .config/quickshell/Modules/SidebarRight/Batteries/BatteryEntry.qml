pragma ComponentBehavior: Bound

import qs.Modules.Common
import qs.Modules.Common.Widgets
import qs.Services
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    required property var device
    readonly property color batteryColor: !device.available ? Appearance.colors.colSubtext
        : DeviceBatteries.isLow(device) ? Appearance.m3colors.m3error : Appearance.colors.colPrimary

    implicitHeight: content.implicitHeight + 24
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer2

    ColumnLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 10

        RowLayout {
            spacing: 10

            MaterialSymbol {
                iconSize: 26
                text: root.device.icon
                color: Appearance.colors.colOnLayer2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.normal
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: root.device.name
                }
                StyledText {
                    Layout.fillWidth: true
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    text: DeviceBatteries.statusText(root.device)
                }
            }

            MaterialSymbol {
                iconSize: 24
                text: DeviceBatteries.batteryIcon(root.device)
                color: root.batteryColor
            }
            StyledText {
                id: levelLabel
                visible: root.device.available
                Layout.minimumWidth: widestLevel.advanceWidth
                horizontalAlignment: Text.AlignRight
                font.pixelSize: Appearance.font.pixelSize.normal
                color: root.batteryColor
                text: DeviceBatteries.levelText(root.device)

                TextMetrics {
                    id: widestLevel
                    font: levelLabel.font
                    text: "~100%"
                }
            }

            RippleButtonWithIcon {
                visible: !root.device.connected && root.device.connect !== null
                enabled: !root.device.connecting
                materialIcon: "bluetooth_connected"
                mainText: qsTr("Connect")
                onClicked: root.device.connect()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: Appearance.colors.colLayer3
            visible: root.device.available && root.device.percentage !== null

            Rectangle {
                width: parent.width * (root.device.percentage ?? 0) / 100
                height: parent.height
                radius: parent.radius
                color: root.batteryColor
            }
        }
    }
}
