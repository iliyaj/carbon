import QtQuick
import qs.Modules.Common
import qs.Modules.Common.Widgets

RippleButton { // hyprbars already draws the close dot in macOS style
    id: root

    visible: ConfigOptions.windows.controlsStyle !== "macos"
    implicitWidth: visible ? 35 : 0
    implicitHeight: 35
    buttonRadius: Appearance.rounding.full
    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        text: "close"
        iconSize: 20
    }
}
