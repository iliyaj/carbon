import "root:/Modules/Common"
import "root:/Services"
import "root:/Modules/Common/Functions/string_utils.js" as StringUtils
import "root:/Modules/Common/Functions/color_utils.js" as ColorUtils
import "./notification_utils.js" as NotificationUtils
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Notifications

/**
 * A group of notifications from the same app.
 * Similar to Android's notifications
 */
Item { // Notification group area
    id: root
    property var notificationGroup
    // A removed ListView delegate outlives its model data during the exit transition.
    property var displayGroup: ({
        "appName": "",
        "appIcon": "",
        "time": 0,
        "notifications": [],
        "mainImage": "",
        "iconSummary": "",
        "latestImage": "",
        "title": "",
    })
    property var notifications: displayGroup.notifications
    property int notificationCount: notifications.length
    property bool multipleNotifications: notificationCount > 1
    property bool expanded: false
    property bool popup: false
    property real padding: 10
    implicitHeight: background.implicitHeight

    property real dragConfirmThreshold: 70 // Drag further to discard notification
    property real dismissOvershoot: 20 // Account for gaps and bouncy animations
    property var dismissIds: []
    property var qmlParent: root.ListView.view
    property var parentDragIndex: qmlParent?.dragIndex ?? -1
    property var parentDragDistance: qmlParent?.dragDistance ?? 0
    property var dragIndexDiff: Math.abs(parentDragIndex - (index ?? 0))
    property real xOffset: dragIndexDiff == 0 ? Math.max(0, parentDragDistance) :
        parentDragDistance > dragConfirmThreshold ? 0 :
        dragIndexDiff == 1 ? Math.max(0, parentDragDistance * 0.3) :
        dragIndexDiff == 2 ? Math.max(0, parentDragDistance * 0.1) : 0

    function captureGroup(group) {
        if (!group || !group.notifications || group.notifications.length === 0)
            return;

        const notifications = group.notifications.slice();
        const first = notifications[0];
        const latest = notifications[notifications.length - 1];
        const multiple = notifications.length > 1;
        root.displayGroup = {
            "appName": group.appName ?? "",
            "appIcon": group.appIcon ?? "",
            "time": group.time ?? 0,
            "notifications": notifications,
            "mainImage": multiple ? "" : (first?.image ?? ""),
            "iconSummary": latest?.summary ?? "",
            "latestImage": latest?.image ?? "",
            "title": multiple ? (group.appName ?? "") : (first?.summary ?? ""),
        };
    }

    onNotificationGroupChanged: captureGroup(notificationGroup)
    Component.onCompleted: captureGroup(notificationGroup)

    function destroyWithAnimation() {
        if (destroyAnimation.running)
            return;

        root.dismissIds = root.notifications.map(notif => notif.id);
        if (root.qmlParent) root.qmlParent.resetDrag()
        background.anchors.leftMargin = background.anchors.leftMargin; // Break binding
        destroyAnimation.running = true;
    }

    SequentialAnimation { // Drag finish animation
        id: destroyAnimation
        running: false

        NumberAnimation {
            target: background.anchors
            property: "leftMargin"
            to: root.width + root.dismissOvershoot
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
        onFinished: () => {
            Notifications.discardNotifications(root.dismissIds);
        }
    }

    function toggleExpanded() {
        if (expanded) implicitHeightAnim.enabled = true;
        else implicitHeightAnim.enabled = false;
        root.expanded = !root.expanded;
    }

    DragManager { // Drag manager
        id: dragManager
        anchors.fill: parent
        interactive: !expanded || notificationCount === 1
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                root.toggleExpanded();
            else if (mouse.button === Qt.MiddleButton)
                root.destroyWithAnimation();
        }

        onDraggingChanged: () => {
            if (dragging && root.qmlParent) {
                root.qmlParent.dragIndex = root.index ?? root.parent?.children?.indexOf(root) ?? 0;
            }
        }

        onDragDiffXChanged: () => {
            if (root.qmlParent) root.qmlParent.dragDistance = dragDiffX;
        }

        onDragReleased: (diffX, diffY) => {
            if (diffX > root.dragConfirmThreshold)
                root.destroyWithAnimation();
            else
                dragManager.resetDrag();
        }
    }

    StyledRectangularShadow {
        target: background
        visible: popup
    }
    Rectangle { // Background of the notification
        id: background
        anchors.left: parent.left
        width: parent.width
        color: Appearance.colors.colSurfaceContainer
        radius: Appearance.rounding.normal
        anchors.leftMargin: root.xOffset

        Behavior on anchors.leftMargin {
            enabled: !dragManager.dragging
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }

        clip: true
        implicitHeight: expanded ?
            row.implicitHeight + padding * 2 :
            Math.min(80, row.implicitHeight + padding * 2)

        Behavior on implicitHeight {
            id: implicitHeightAnim
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        RowLayout { // Left column for icon, right column for content
            id: row
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.padding
            spacing: 10

            NotificationAppIcon { // Icons
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: false
                image: root.displayGroup.mainImage
                appIcon: root.displayGroup.appIcon
                summary: root.displayGroup.iconSummary
            }

            ColumnLayout { // Content
                Layout.fillWidth: true
                spacing: expanded ? (root.multipleNotifications ?
                    (root.displayGroup.latestImage != "") ? 35 :
                    5 : 0) : 0
                // spacing: 00
                Behavior on spacing {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                Item { // App name (or summary when there's only 1 notif) and time
                    id: topRow
                    // spacing: 0
                    Layout.fillWidth: true
                    property real fontSize: Appearance.font.pixelSize.smaller
                    property bool showAppName: root.multipleNotifications
                    implicitHeight: Math.max(topTextRow.implicitHeight, expandButton.implicitHeight)

                    RowLayout {
                        id: topTextRow
                        anchors.left: parent.left
                        anchors.right: expandButton.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        StyledText {
                            id: appName
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            text: root.displayGroup.title
                            font.pixelSize: topRow.showAppName ?
                                topRow.fontSize :
                                Appearance.font.pixelSize.small
                            color: topRow.showAppName ?
                                Appearance.colors.colSubtext :
                                Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            id: timeText
                            // Layout.fillWidth: true
                            Layout.rightMargin: 10
                            horizontalAlignment: Text.AlignLeft
                            text: NotificationUtils.getFriendlyNotifTimeString(root.displayGroup.time)
                            font.pixelSize: topRow.fontSize
                            color: Appearance.colors.colSubtext
                        }
                    }
                    NotificationGroupExpandButton {
                        id: expandButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        count: root.notificationCount
                        expanded: root.expanded
                        fontSize: topRow.fontSize
                        onClicked: { root.toggleExpanded() }
                    }
                }

                StyledListView { // Notification body (expanded)
                    id: notificationsColumn
                    implicitHeight: contentHeight
                    Layout.fillWidth: true
                    spacing: expanded ? 5 : 3
                    // clip: true
                    interactive: false
                    Behavior on spacing {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    model: ScriptModel {
                        values: root.expanded ? root.notifications.slice().reverse() :
                            root.notifications.slice().reverse().slice(0, 2)
                        objectProp: "id"
                    }
                    delegate: NotificationItem {
                        required property int index
                        required property var modelData
                        notificationObject: modelData
                        expanded: root.expanded
                        onlyNotification: (root.notificationCount === 1)
                        opacity: (!root.expanded && index == 1 && root.notificationCount > 2) ? 0.5 : 1
                        visible: root.expanded || (index < 2)
                        width: ListView.view.width
                        onDismissGroupRequested: root.destroyWithAnimation()
                    }
                }

            }
        }
    }
}
