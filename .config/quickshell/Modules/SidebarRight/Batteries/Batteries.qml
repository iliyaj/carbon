pragma ComponentBehavior: Bound

import qs.Modules.Common
import qs.Modules.Common.Widgets
import qs.Services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    Flickable {
        anchors.fill: parent
        clip: true
        contentHeight: entries.implicitHeight + 20
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: entries
            x: 10
            y: 10
            width: parent.width - 20
            spacing: 10

            Repeater {
                model: DeviceBatteries.devices

                BatteryEntry {
                    required property var modelData
                    Layout.fillWidth: true
                    device: modelData
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: DeviceBatteries.devices.length === 0
        spacing: 5

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            iconSize: 55
            color: Appearance.m3colors.m3outline
            text: "battery_unknown"
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            color: Appearance.m3colors.m3outline
            text: qsTr("No battery devices")
        }
    }
}
