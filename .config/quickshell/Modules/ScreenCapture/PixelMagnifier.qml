pragma ComponentBehavior: Bound

import qs.Modules.Common
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property var pixel: null
    implicitWidth: 164
    implicitHeight: 192
    color: Appearance.m3colors.m3surfaceContainerHigh
    border.color: Appearance.m3colors.m3outline
    radius: 8

    Item {
        x: 16; y: 12; width: 132; height: 132
        Repeater {
            model: root.pixel?.colors ?? []
            delegate: Rectangle {
                required property int index
                required property string modelData
                x: index % 11 * 12; y: Math.floor(index / 11) * 12
                width: 12; height: 12
                color: modelData
            }
        }
        Rectangle { x: 60; y: 60; width: 12; height: 12; color: "transparent"; border.width: 1; border.color: "white" }
        Rectangle { x: 59; y: 59; width: 14; height: 14; color: "transparent"; border.width: 1; border.color: "black" }
    }
    Text {
        x: 12; y: 152; width: parent.width - 24
        text: root.pixel ? root.pixel.x + ", " + root.pixel.y + "\n" + root.pixel.color : ""
        color: Appearance.m3colors.m3onSurface
        horizontalAlignment: Text.AlignHCenter
    }
}
