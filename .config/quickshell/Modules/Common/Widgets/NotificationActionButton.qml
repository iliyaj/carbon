import "root:/Modules/Common"
import "root:/Services"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

RippleButton {
    id: button
    property string buttonText
    property string urgency: String(NotificationUrgency.Normal)
    readonly property bool isCritical: urgency === String(NotificationUrgency.Critical)

    implicitHeight: 30
    leftPadding: 15
    rightPadding: 15
    buttonRadius: Appearance.rounding.small
    colBackground: isCritical ? Appearance.colors.colSecondaryContainer : Appearance.colors.colSurfaceContainerHighest
    colBackgroundHover: isCritical ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSurfaceContainerHighestHover
    colRipple: isCritical ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colSurfaceContainerHighestActive

    contentItem: StyledText {
        horizontalAlignment: Text.AlignHCenter
        text: buttonText
        color: button.isCritical ? Appearance.m3colors.m3onSurfaceVariant : Appearance.m3colors.m3onSurface
    }
}
