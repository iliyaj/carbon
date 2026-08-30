import "root:/Modules/Common"
import "root:/Modules/Common/Functions"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

Rectangle { // App icon
    id: root
    property var appIcon: ""
    property var summary: ""
    property var urgency: NotificationUrgency.Normal
    property var image: ""
    property real scale: 1
    property real size: 45 * scale
    property real materialIconScale: 0.57
    property real appIconScale: 0.7
    property real smallAppIconScale: 0.49
    property real materialIconSize: size * materialIconScale
    property real appIconSize: size * appIconScale
    property real smallAppIconSize: size * smallAppIconScale

    implicitWidth: size
    implicitHeight: size
    radius: Appearance.rounding.full
    color: Appearance.colors.colSecondaryContainer

    function resolvedAppIcon(icon) {
        // Screenshot tools commonly put an absolute image path in app_icon.
        const value = String(icon ?? "")
        if (value.startsWith("/") || value.startsWith("file://"))
            return Qt.resolvedUrl(value)
        return Quickshell.iconPath(value, "image-missing")
    }

    function resolvedNotificationImage(image) {
        const value = String(image ?? "")
        const iconProviderPrefix = "image://icon/"
        if (value.startsWith(iconProviderPrefix)) {
            const iconPayload = value.slice(iconProviderPrefix.length)
            if (iconPayload.startsWith("/") || iconPayload.startsWith("file://"))
                return Qt.resolvedUrl(iconPayload)
        }
        if (value.startsWith("/") || value.startsWith("file://"))
            return Qt.resolvedUrl(value)
        return value
    }

    // Keep every icon layer instantiated so source changes cannot rebuild the card in stages.
    MaterialSymbol {
        visible: root.image == "" && root.appIcon == ""
        anchors.fill: parent
        text: {
            const defaultIcon = NotificationUtils.findSuitableMaterialSymbol("")
            const guessedIcon = NotificationUtils.findSuitableMaterialSymbol(root.summary)
            return (root.urgency == NotificationUrgency.Critical && guessedIcon === defaultIcon) ?
                "release_alert" : guessedIcon
        }
        color: (root.urgency == NotificationUrgency.Critical) ?
            ColorUtils.mix(Appearance.m3colors.m3onSecondary, Appearance.m3colors.m3onSecondaryContainer, 0.1) :
            Appearance.m3colors.m3onSecondaryContainer
        iconSize: root.materialIconSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    IconImage {
        visible: root.image == "" && root.appIcon != ""
        anchors.centerIn: parent
        implicitSize: root.appIconSize
        asynchronous: false
        source: visible ? root.resolvedAppIcon(root.appIcon) : ""
    }

    Item {
        visible: root.image != ""
        anchors.fill: parent
        Image {
            id: notifImage
            anchors.fill: parent
            readonly property int size: parent.width

            source: visible ? root.resolvedNotificationImage(root.image) : ""
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            asynchronous: false

            width: size
            height: size
            sourceSize.width: size
            sourceSize.height: size

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: notifImage.size
                    height: notifImage.size
                    radius: Appearance.rounding.full
                }
            }
        }
        IconImage {
            visible: root.appIcon != ""
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            implicitSize: root.smallAppIconSize
            asynchronous: false
            source: visible ? root.resolvedAppIcon(root.appIcon) : ""
        }
    }
}
