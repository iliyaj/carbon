import qs.Modules.Common
import qs.Modules.Common.Functions
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

MouseArea {
    id: root

    required property var bar
    required property SystemTrayItem item
    property int trayItemWidth: Appearance.font.pixelSize.larger

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    Layout.fillHeight: true
    implicitWidth: trayItemWidth
    onClicked: (event) => {
        switch (event.button) {
        case Qt.LeftButton:
            item.activate();
            break;
        case Qt.RightButton:
            if (item.hasMenu) {
                const position = root.mapToItem(root.bar.contentItem, 0, root.height)
                item.display(root.bar, position.x, position.y)
            }
            break;
        }
        event.accepted = true;
    }

    IconImage {
        id: trayIcon
        // Keep opacity 0 (not visible: false) so Desaturate can still sample its texture
        opacity: ConfigOptions.bar.tray.monochromeIcons ? 0 : 1
        source: root.item.icon
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
    }

    Loader {
        active: ConfigOptions.bar.tray.monochromeIcons
        anchors.fill: trayIcon
        sourceComponent: Item {
            Desaturate {
                id: desaturatedIcon
                visible: false // There's already color overlay
                anchors.fill: parent
                source: trayIcon
                desaturation: 1 // 1.0 means fully grayscale
            }
            ColorOverlay {
                anchors.fill: desaturatedIcon
                source: desaturatedIcon
                color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.6)
            }
        }
    }

}
