import "root:/Modules/Common"
import "root:/Services"
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Item {
    id: root
    property bool borderless: ConfigOptions.bar.borderless
    property bool alwaysShowAllResources: false
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: 32

    RowLayout {
        id: rowLayout

        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Resource {
            label: qsTr("RAM")
            percentage: ResourceUsage.memoryUsedPercentage
        }

        Resource {
            label: qsTr("Swap")
            percentage: ResourceUsage.swapUsedPercentage
            shown: (ConfigOptions.bar.resources.alwaysShowSwap && percentage > 0) ||
                (MprisController.activePlayer?.trackTitle == null) ||
                root.alwaysShowAllResources
            Layout.leftMargin: shown ? 4 : 0
        }

        Resource {
            label: qsTr("CPU")
            percentage: ResourceUsage.cpuUsage
            Layout.leftMargin: 4
        }

    }

}
