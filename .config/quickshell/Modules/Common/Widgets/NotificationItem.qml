import "root:/Modules/Common"
import "root:/Services"
import "root:/Modules/Common/Functions"
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

Item { // Notification item area
    id: root
    property var notificationObject
    // Preserve display data while ListView finishes removing an invalidated model row.
    property var notificationData: ({
        "id": -1,
        "actions": [],
        "appIcon": "",
        "appName": "",
        "body": "",
        "image": "",
        "summary": "",
        "time": 0,
        "urgency": String(NotificationUrgency.Normal),
    })
    readonly property bool isCritical: notificationData.urgency === String(NotificationUrgency.Critical)
    // The default action belongs to the notification card, not the visible button row.
    readonly property var defaultAction: notificationData.actions.find(action => action.identifier === "default") ?? null
    readonly property var visibleActions: notificationData.actions.filter(action =>
        action.identifier !== "default" && String(action.text ?? "").trim().length > 0)
    property bool expanded: false
    property bool onlyNotification: false
    property real fontSize: Appearance.font.pixelSize.small
    property real padding: onlyNotification ? 0 : 8
    signal dismissGroupRequested

    // capture path behind the Annotate action
    function screenshotPathFor(n) {
        for (const candidate of [n.image, n.appIcon]) {
            const localPath = NotificationUtils.localImagePath(candidate);
            if (/\.(png|jpe?g)$/i.test(localPath))
                return localPath;
        }
        const m = /Image saved in\s*<i>(.*?)<\/i>/.exec(n.body ?? "");
        if (m) return m[1];
        return "";
    }
    property string screenshotPath: screenshotPathFor(notificationData)
    property bool isScreenshot: screenshotPath.length > 0 &&
        (String(notificationData.appName).toLowerCase().includes("hyprshot")
         || String(notificationData.summary).toLowerCase().includes("screenshot")
         || screenshotPath.includes("/Screenshots/"))

    // Always-present icon buttons (Close, Copy, and Annotate for screenshots) share
    // the row evenly when the notification carries no dbus actions of its own.
    property int fillerButtonCount: 2 + (isScreenshot ? 1 : 0)

    property real dragConfirmThreshold: 70 // Drag further to discard notification
    property real dismissOvershoot: notificationIcon.implicitWidth + 20 // Account for gaps and bouncy animations
    property var qmlParent: root.ListView.view
    property var parentDragIndex: qmlParent?.dragIndex ?? -1
    property var parentDragDistance: qmlParent?.dragDistance ?? 0
    property var dragIndexDiff: Math.abs(parentDragIndex - index)
    property real xOffset: dragIndexDiff == 0 ? Math.max(0, parentDragDistance) :
        parentDragDistance > dragConfirmThreshold ? 0 :
        dragIndexDiff == 1 ? Math.max(0, parentDragDistance * 0.3) :
        dragIndexDiff == 2 ? Math.max(0, parentDragDistance * 0.1) : 0

    implicitHeight: background.implicitHeight

    function captureNotification(notification) {
        if (!notification || notification.closing)
            return;

        root.notificationData = {
            "id": notification.id,
            "actions": (notification.actions ?? []).map(action => ({
                "identifier": action.identifier,
                "text": action.text,
            })),
            "appIcon": notification.appIcon ?? "",
            "appName": notification.appName ?? "",
            "body": notification.body ?? "",
            "image": notification.image ?? "",
            "summary": notification.summary ?? "",
            "time": notification.time ?? 0,
            "urgency": notification.urgency ?? String(NotificationUrgency.Normal),
        };
    }

    onNotificationObjectChanged: captureNotification(notificationObject)
    Component.onCompleted: captureNotification(notificationObject)

    Connections {
        target: root.notificationObject
        ignoreUnknownSignals: true
        function onActionsChanged() { root.captureNotification(root.notificationObject); }
        function onAppIconChanged() { root.captureNotification(root.notificationObject); }
        function onAppNameChanged() { root.captureNotification(root.notificationObject); }
        function onBodyChanged() { root.captureNotification(root.notificationObject); }
        function onImageChanged() { root.captureNotification(root.notificationObject); }
        function onSummaryChanged() { root.captureNotification(root.notificationObject); }
        function onTimeChanged() { root.captureNotification(root.notificationObject); }
        function onUrgencyChanged() { root.captureNotification(root.notificationObject); }
    }

    function processNotificationBody(body, appName) {
        let processedBody = body

        // Clean Chromium-based browsers notifications - remove first line
        if (appName) {
            const lowerApp = appName.toLowerCase()
            const chromiumBrowsers = [
                "brave", "chrome", "chromium", "vivaldi", "opera", "microsoft edge"
            ]

            if (chromiumBrowsers.some(name => lowerApp.includes(name))) {
                const lines = body.split('\n\n')

                if (lines.length > 1 && lines[0].startsWith('<a')) {
                    processedBody = lines.slice(1).join('\n\n')
                }
            }
        }

        // Insert zero-width spaces after '/' so long paths wrap inside RichText inline elements
        processedBody = processedBody.replace(/(<[^>]+>)|(\/)(?=[^\s<])/g, (match, tag, slash) => {
            if (tag) return tag;
            return slash + "&#8203;";
        });

        return processedBody
    }

    function destroyWithAnimation() {
        if (root.onlyNotification) {
            root.dismissGroupRequested();
            return;
        }
        if (destroyAnimation.running)
            return;

        root.qmlParent.resetDrag()
        background.anchors.leftMargin = background.anchors.leftMargin; // Break binding
        destroyAnimation.running = true;
    }

    function invokeDefaultAction() {
        if (!root.defaultAction)
            return;

        Notifications.attemptInvokeAction(notificationData.id, root.defaultAction.identifier);
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
            Notifications.discardNotification(notificationData.id);
        }
    }

    DragManager { // Drag manager
        id: dragManager
        anchors.fill: root
        anchors.leftMargin: root.expanded ? -notificationIcon.implicitWidth : 0
        interactive: expanded && !onlyNotification
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                root.destroyWithAnimation();
            } else if (mouse.button === Qt.LeftButton && !dragManager.movedBeyondClickThreshold) {
                root.invokeDefaultAction();
            }
        }

        onDraggingChanged: () => {
            if (dragging) {
                root.qmlParent.dragIndex = root.index ?? root.parent.children.indexOf(root);
            }
        }

        onDragDiffXChanged: () => {
            root.qmlParent.dragDistance = dragDiffX;
        }

        onDragReleased: (diffX, diffY) => {
            if (diffX > root.dragConfirmThreshold)
                root.destroyWithAnimation();
            else
                dragManager.resetDrag();
        }
    }

    NotificationAppIcon { // App icon
        id: notificationIcon
        opacity: (!onlyNotification && notificationData.image != "" && expanded) ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        image: notificationData.image
        anchors.right: background.left
        anchors.top: background.top
        anchors.rightMargin: 10
    }

    Rectangle { // Background of notification item
        id: background
        width: parent.width
        anchors.left: parent.left
        radius: Appearance.rounding.small
        anchors.leftMargin: root.xOffset

        Behavior on anchors.leftMargin {
            enabled: !dragManager.dragging
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }

        color: (expanded && !onlyNotification) ?
            root.isCritical ?
                ColorUtils.mix(Appearance.colors.colSecondaryContainer, Appearance.colors.colLayer2, 0.35) :
                (Appearance.colors.colSurfaceContainerHigh) :
            ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHighest)

        implicitHeight: expanded ? (contentColumn.implicitHeight + padding * 2) : summaryRow.implicitHeight
        // elementMove overshoots; match the group height and the margins instead
        Behavior on implicitHeight {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        ColumnLayout { // Content column
            id: contentColumn
            anchors.fill: parent
            anchors.margins: expanded ? root.padding : 0
            spacing: 3

            Behavior on anchors.margins {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            RowLayout { // Summary row
                id: summaryRow
                visible: !root.onlyNotification || !root.expanded
                Layout.fillWidth: true
                implicitHeight: summaryText.implicitHeight
                // Layout.fillWidth: true
                StyledText {
                    id: summaryText
                    visible: !root.onlyNotification
                    font.pixelSize: root.fontSize
                    color: Appearance.colors.colOnLayer2
                    elide: Text.ElideRight
                    text: root.notificationData.summary
                }
                StyledText {
                    // no fade-in; the expanded body leaves instantly and a gap reads as a blink
                    visible: !root.expanded
                    Layout.fillWidth: true
                    font.pixelSize: root.fontSize
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.StyledText
                    text: {
                        return processNotificationBody(notificationData.body, notificationData.appName || notificationData.summary).replace(/\n/g, "<br/>")
                    }
                }
            }

            ColumnLayout { // Expanded content
                Layout.fillWidth: true
                opacity: root.expanded ? 1 : 0
                visible: opacity > 0

                StyledText { // Notification body (expanded)
                    id: notificationBodyText
                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    Layout.fillWidth: true
                    font.pixelSize: root.fontSize
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    textFormat: Text.RichText
                    text: {
                        const availableWidth = Math.max(1, background.width - root.padding * 2);
                        return `<style>img{max-width:${availableWidth}px;}</style>` +
                               `${processNotificationBody(notificationData.body, notificationData.appName || notificationData.summary).replace(/\n/g, "<br/>")}`
                    }

                    onLinkActivated: (link) => {
                        Qt.openUrlExternally(link)
                        Hyprland.dispatch("hl.dsp.global([[quickshell:sidebarRightClose]])")
                    }

                    PointingHandLinkHover {}
                }

                Flickable { // Notification actions
                    id: actionsFlickable
                    Layout.fillWidth: true
                    implicitHeight: actionRowLayout.implicitHeight
                    contentWidth: actionRowLayout.implicitWidth
                    clip: !onlyNotification

                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    Behavior on implicitHeight {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    RowLayout {
                        id: actionRowLayout
                        Layout.alignment: Qt.AlignBottom

                        NotificationActionButton {
                            Layout.fillWidth: true
                            buttonText: qsTr("Close")
                            urgency: notificationData.urgency
                            implicitWidth: (root.visibleActions.length == 0) ?
                                ((actionsFlickable.width - actionRowLayout.spacing * (root.fillerButtonCount - 1)) / root.fillerButtonCount) :
                                (contentItem.implicitWidth + leftPadding + rightPadding)

                            onClicked: {
                                root.destroyWithAnimation()
                            }

                            contentItem: MaterialSymbol {
                                iconSize: Appearance.font.pixelSize.large
                                horizontalAlignment: Text.AlignHCenter
                                color: root.isCritical ?
                                    Appearance.m3colors.m3onSurfaceVariant : Appearance.m3colors.m3onSurface
                                text: "close"
                            }
                        }

                        NotificationActionButton { // Annotate screenshot
                            visible: root.isScreenshot
                            Layout.fillWidth: true
                            urgency: notificationData.urgency
                            implicitWidth: (root.visibleActions.length == 0) ?
                                ((actionsFlickable.width - actionRowLayout.spacing * (root.fillerButtonCount - 1)) / root.fillerButtonCount) :
                                (contentItem.implicitWidth + leftPadding + rightPadding)
                            onClicked: {
                                Quickshell.execDetached(["env", "ANNOTATE_IMG=" + root.screenshotPath,
                                    "qs", "-p", FileUtils.trimFileProtocol(`${Directories.config}/quickshell/annotator.qml`)]);
                            }
                            contentItem: MaterialSymbol {
                                iconSize: Appearance.font.pixelSize.large
                                horizontalAlignment: Text.AlignHCenter
                                color: root.isCritical ?
                                    Appearance.m3colors.m3onSurfaceVariant : Appearance.m3colors.m3onSurface
                                text: "draw"
                            }
                        }

                        Repeater {
                            id: actionRepeater
                            model: root.visibleActions
                            NotificationActionButton {
                                Layout.fillWidth: true
                                buttonText: modelData.text
                                urgency: notificationData.urgency
                                onClicked: {
                                    Notifications.attemptInvokeAction(notificationData.id, modelData.identifier);
                                }
                            }
                        }

                        NotificationActionButton {
                            Layout.fillWidth: true
                            urgency: notificationData.urgency
                            implicitWidth: (root.visibleActions.length == 0) ?
                                ((actionsFlickable.width - actionRowLayout.spacing * (root.fillerButtonCount - 1)) / root.fillerButtonCount) :
                                (contentItem.implicitWidth + leftPadding + rightPadding)

                            onClicked: {
                                Quickshell.clipboardText = root.isScreenshot ? root.screenshotPath
                                    : StringUtils.stripHtml(notificationData.body)
                                copyIcon.text = "inventory"
                                copyIconTimer.restart()
                            }

                            Timer {
                                id: copyIconTimer
                                interval: 1500
                                repeat: false
                                onTriggered: {
                                    copyIcon.text = "content_copy"
                                }
                            }

                            contentItem: MaterialSymbol {
                                id: copyIcon
                                iconSize: Appearance.font.pixelSize.large
                                horizontalAlignment: Text.AlignHCenter
                                color: root.isCritical ?
                                    Appearance.m3colors.m3onSurfaceVariant : Appearance.m3colors.m3onSurface
                                text: "content_copy"
                            }
                        }

                    }
                }
            }
        }
    }
}
