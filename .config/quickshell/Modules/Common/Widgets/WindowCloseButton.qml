import QtQuick
import qs.Modules.Common
import qs.Modules.Common.Widgets

Item { // matches the hyprbars window-controls style
    id: root

    signal clicked

    readonly property bool macos: ConfigOptions.windows.controlsStyle === "macos"

    implicitWidth: 35
    implicitHeight: 35

    RippleButton {
        visible: !root.macos
        anchors.fill: parent
        buttonRadius: Appearance.rounding.full
        onClicked: root.clicked()
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: "close"
            iconSize: 20
        }
    }

    Rectangle {
        visible: root.macos
        anchors.centerIn: parent
        width: 13
        height: 13
        radius: width / 2
        color: "#e8918b"

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
