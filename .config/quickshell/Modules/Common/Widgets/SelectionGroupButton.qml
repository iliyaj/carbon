import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "root:/Services/"
import "root:/Modules/Common/"
import "root:/Modules/Common/Widgets/"

GroupButton {
    id: root
    horizontalPadding: 12
    verticalPadding: 8
    bounce: false
    property bool leftmost: false
    property bool rightmost: false
    leftRadius: (toggled || leftmost) ? Appearance.rounding.small : Appearance.rounding.unsharpenmore
    rightRadius: (toggled || rightmost) ? Appearance.rounding.small : Appearance.rounding.unsharpenmore
    colBackground: Appearance.colors.colSecondaryContainer
    contentItem: StyledText {
        color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
        text: root.buttonText
    }
}
