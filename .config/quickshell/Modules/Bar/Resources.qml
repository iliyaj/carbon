import "root:/Services"
import QtQuick

Item {
    implicitWidth: memoryResource.implicitWidth + 8
    implicitHeight: 32

    Resource {
        id: memoryResource
        anchors.centerIn: parent
        label: qsTr("RAM")
        percentage: ResourceUsage.memoryUsedPercentage
    }
}
