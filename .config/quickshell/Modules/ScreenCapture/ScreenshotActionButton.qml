pragma ComponentBehavior: Bound

import qs.Modules.Common
import qs.Modules.Common.Widgets
import QtQuick
import QtQuick.Controls

Button {
    id: root
    implicitHeight: 36
    horizontalPadding: 14

    background: Rectangle {
        implicitWidth: 100
        implicitHeight: 36
        radius: Appearance.rounding.small
        color: root.down ? "#44ffffff" : root.hovered ? "#33ffffff" : "#22ffffff"
        border.width: root.activeFocus ? 1 : 0
        border.color: "#eeeeee"
    }
    contentItem: StyledText {
        text: root.text
        color: root.enabled ? "#eeeeee" : "#888888"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
