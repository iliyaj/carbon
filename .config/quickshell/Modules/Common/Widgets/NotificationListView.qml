import "root:/Modules/Common/"
import "root:/Modules/Common/Widgets"
import "root:/Services"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

StyledListView { // Scrollable window
    id: root
    property bool popup: false

    spacing: 3

    model: ScriptModel {
        values: root.popup ? Notifications.popupGroupKeys : Notifications.appNameList
    }
    delegate: NotificationGroup {
        required property int index
        required property var modelData
        popup: root.popup
        width: ListView.view.width
        height: implicitHeight
        notificationGroup: popup ?
            Notifications.popupGroups[modelData] :
            Notifications.groupsByAppName[modelData]
    }
}
