import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RippleButton {
    Layout.fillHeight: true
    Layout.topMargin: Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut
    implicitWidth: implicitHeight - topInset - bottomInset
    buttonRadius: Appearance.rounding.normal

    topInset: Appearance.sizes.hyprlandGapsOut + dockRow.padding
    bottomInset: Appearance.sizes.hyprlandGapsOut + dockRow.padding
}
