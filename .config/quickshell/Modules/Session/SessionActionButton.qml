import qs.Modules.Common
import qs.Modules.Common.Widgets
import qs.Modules.Common.Functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RippleButton {
    id: button

    property string buttonIcon
    property string buttonText
    property bool keyboardDown: false
    property real size: 120

    buttonRadius: Appearance.rounding.verylarge
    colBackground: button.keyboardDown ? Appearance.colors.colSecondaryContainerActive :
        Appearance.colors.colSecondaryContainer
    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
    colRipple: Appearance.colors.colPrimaryActive
    property color colText: Appearance.colors.colOnLayer0

    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    background.implicitHeight: size
    background.implicitWidth: size

    onHoveredChanged: {
        if (hovered)
            button.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        z: 2
        visible: button.activeFocus
        color: "transparent"
        radius: button.buttonRadius
        border.width: 2
        border.color: Appearance.colors.colPrimary
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            keyboardDown = true
            button.clicked()
            event.accepted = true;
        }
    }
    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            keyboardDown = false
            event.accepted = true;
        }
    }

    contentItem: MaterialSymbol {
        id: icon
        anchors.fill: parent
        color: button.colText
        horizontalAlignment: Text.AlignHCenter
        iconSize: 45
        text: buttonIcon
    }

    StyledToolTip {
        content: buttonText
    }

}
