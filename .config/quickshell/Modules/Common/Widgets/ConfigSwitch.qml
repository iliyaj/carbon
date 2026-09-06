import qs.Modules.Common.Widgets
import qs.Modules.Common
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

RippleButton {
    id: root
    Layout.fillWidth: true
    implicitHeight: contentItem.implicitHeight + 8 * 2
    onClicked: checked = !checked

    contentItem: RowLayout {
        spacing: 10
        opacity: root.enabled ? 1 : 0.4 // Without this a disabled switch looks live but ignores clicks

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        StyledText {
            id: labelWidget
            Layout.fillWidth: true
            text: root.text
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSecondaryContainer
        }
        StyledSwitch {
            id: switchWidget
            down: root.down
            scale: 0.6
            Layout.fillWidth: false
            checked: root.checked
            onClicked: root.clicked()
        }
    }
}
