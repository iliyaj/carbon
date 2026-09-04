pragma Singleton
pragma ComponentBehavior: Bound

import "root:/Modules/Common"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

/**
 * Provides extra features not in Quickshell.Services.Notifications:
 *  - Persistent storage
 *  - Popup notifications, with timeout
 *  - Notification groups by app
 */
Singleton {
	id: root
    component Notif: QtObject {
        id: notif
        required property int id
        property Notification notification
        property list<var> actions: notification?.actions.map((action) => ({
            "identifier": action.identifier,
            "text": action.text,
        })) ?? []
        property bool popup: false
        property string appIcon: notification?.appIcon ?? ""
        property string appName: notification?.appName ?? ""
        property string body: notification?.body ?? ""
        property string desktopEntry: notification?.desktopEntry ?? ""
        property string image: notification?.image ?? ""
        property string summary: notification?.summary ?? ""
        property double time
        property bool isTransient: notification?.transient ?? false
        property string urgency: notification?.urgency.toString() ?? "normal"
        property Timer timer
        property bool closing: false // Keep destroyed source bindings from blanking an exiting row
        property Connections notificationLifecycle: Connections {
            target: notif.notification

            function persistUpdate() {
                if (!notif.closing)
                    root.schedulePersist();
            }

            function refreshTimer() {
                if (!notif.closing)
                    root.restartPopupTimer(notif);
            }

            function onAppIconChanged() { persistUpdate(); }
            function onAppNameChanged() { persistUpdate(); }
            function onBodyChanged() { persistUpdate(); }
            function onClosed() {
                notif.closing = true;
                root.removeClosedNotification(notif.id);
            }
            function onDesktopEntryChanged() { persistUpdate(); }
            function onExpireTimeoutChanged() { refreshTimer(); }
            function onImageChanged() { persistUpdate(); }
            function onSummaryChanged() { persistUpdate(); }
            function onTransientChanged() {
                persistUpdate();
                refreshTimer();
            }
            function onUrgencyChanged() {
                persistUpdate();
                refreshTimer();
            }
        }
    }

    function notifToJSON(notif) {
        return {
            "id": notif.id,
            "actions": notif.actions,
            "appIcon": notif.appIcon,
            "appName": notif.appName,
            "body": notif.body,
            "desktopEntry": notif.desktopEntry,
            "image": notif.image,
            "summary": notif.summary,
            "time": notif.time,
            "urgency": notif.urgency,
        }
    }
    function notifToString(notif) {
        return JSON.stringify(notifToJSON(notif), null, 2);
    }

    component NotifTimer: Timer {
        required property int id
        property int remaining: interval
        property double startedAt: 0
        property bool firing: false
        interval: 5000
        running: true

        function pause() {
            if (!running || firing)
                return;
            remaining = Math.max(1, remaining - Math.max(0, Date.now() - startedAt));
            stop();
        }

        function resume() {
            if (running || firing || remaining <= 0)
                return;
            interval = remaining;
            startedAt = Date.now();
            start();
        }

        onRunningChanged: {
            if (running)
                startedAt = Date.now();
        }
        onTriggered: () => {
            firing = true;
            root.handlePopupTimeout(id);
            destroy()
        }

        Component.onCompleted: {
            remaining = interval;
            startedAt = Date.now();
        }
    }

    property bool silent: false
    property var filePath: Directories.notificationsPath
    property list<Notif> list: []
    property var popupList: list.filter((notif) => notif.popup);
    property bool popupInhibited: (GlobalStates?.sidebarRightOpen ?? false) || silent
    property var pausedPopupIds: new Set()
    Component {
        id: notifComponent
        Notif {}
    }
    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    property int maxRetained: ConfigOptions?.notifications?.maxRetained ?? 200
    property int persistDebounce: ConfigOptions?.notifications?.persistDebounce ?? 500
    property int popupTimeout: ConfigOptions?.notifications?.timeout ?? 5000

    function stringifyList(list) {
        return JSON.stringify(list.filter(notif => !notif.isTransient).map((notif) => notifToJSON(notif)));
    }

    Timer {
        id: persistTimer
        interval: root.persistDebounce
        repeat: false
        onTriggered: notifFileView.setText(root.stringifyList(root.list))
    }

    function schedulePersist() {
        persistTimer.restart();
    }

    function trimList() {
        if (root.maxRetained <= 0)
            return;

        const current = [...root.list];
        const overflow = current.length - root.maxRetained;
        if (overflow <= 0)
            return;

        const evicted = current.slice(0, overflow);
        root.list = current.slice(overflow);
        evicted.forEach(notif => {
            if (notif.timer)
                notif.timer.destroy();
            Qt.callLater(() => notif.destroy());
        });
    }

    function groupKeyForNotification(notif) {
        const appName = String(notif.appName ?? "").trim();
        if (appName.length > 0)
            return `app:${appName}`;

        const desktopEntry = String(notif.desktopEntry ?? "").trim();
        if (desktopEntry.length > 0)
            return `desktop:${desktopEntry}`;

        return `notification:${notif.id}`;
    }

    function displayNameForNotification(notif) {
        const appName = String(notif.appName ?? "").trim();
        if (appName.length > 0)
            return appName;

        const desktopEntry = String(notif.desktopEntry ?? "").trim();
        if (desktopEntry.length > 0) {
            const entry = DesktopEntries.byId(desktopEntry);
            return String(entry?.name ?? "").trim() || desktopEntry;
        }

        return String(notif.summary ?? "").trim() || qsTr("Notification");
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => {
            // Sort by time, descending
            return groups[b].time - groups[a].time;
        });
    }

    function groupsForList(list, individualNotifications = false) {
        const groups = Object.create(null);
        list.forEach((notif) => {
            const groupKey = individualNotifications ?
                `notification:${notif.id}` : root.groupKeyForNotification(notif);
            if (!Object.prototype.hasOwnProperty.call(groups, groupKey)) {
                groups[groupKey] = {
                    appName: root.displayNameForNotification(notif),
                    appIcon: notif.appIcon,
                    notifications: [],
                    time: 0
                };
            }
            const group = groups[groupKey];
            group.notifications.push(notif);
            if (notif.time >= group.time) {
                group.time = notif.time;
                group.appName = root.displayNameForNotification(notif);
                if (notif.appIcon)
                    group.appIcon = notif.appIcon;
            }
        });
        return groups;
    }

    property var groupsByAppName: groupsForList(root.list)
    property var popupGroups: groupsForList(root.popupList, true)
    property var appNameList: appNameListForGroups(root.groupsByAppName)
    property var popupGroupKeys: appNameListForGroups(root.popupGroups)

    // Quickshell's notification IDs starts at 1 on each run, while saved notifications
    // can already contain higher IDs. This is for avoiding id collisions
    property int idOffset
    signal initDone();
    signal notify(notification: var);
    signal discard(id: var);
    signal discardAll();
    signal timeout(id: var);

	NotificationServer {
        id: notifServer
        // actionIconsSupported: true
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: (notification) => {
            notification.tracked = true
            const newNotifObject = notifComponent.createObject(root, {
                "id": notification.id + root.idOffset,
                "notification": notification,
                "time": Date.now(),
            });
			root.list = [...root.list, newNotifObject];

            // Popup
            if (!root.popupInhibited)
                newNotifObject.popup = true;
            root.restartPopupTimer(newNotifObject);

            root.notify(newNotifObject);
            // console.log(notifToString(newNotifObject));
            root.trimList();
            root.schedulePersist();
        }
    }

    function removeNotifications(ids, dismissTracked) {
        const idSet = new Set(ids);
        const discarded = root.list.filter(notif => idSet.has(notif.id));
        if (discarded.length === 0)
            return;

        // One assignment prevents groups from rendering every intermediate count.
        root.list = root.list.filter(notif => !idSet.has(notif.id));
        root.schedulePersist();

        if (dismissTracked) {
            notifServer.trackedNotifications.values
                .filter(notif => idSet.has(notif.id + root.idOffset))
                .forEach(notif => notif.dismiss());
        }

        discarded.forEach(notif => {
            root.pausedPopupIds.delete(notif.id);
            root.discard(notif.id);
            if (notif.timer && !notif.timer.firing)
                notif.timer.destroy();
            notif.timer = null;
            Qt.callLater(() => notif.destroy());
        });
    }

    function discardNotifications(ids) {
        removeNotifications(ids, true);
    }

    function removeClosedNotification(id) {
        removeNotifications([id], false);
    }

    function discardNotification(id) {
        discardNotifications([id]);
    }

    function discardAllNotifications() {
        discardNotifications(root.list.map(notif => notif.id));
        root.discardAll();
    }

    function timeoutNotification(id) {
        const index = root.list.findIndex((notif) => notif.id === id);
        if (root.list[index] != null)
            root.list[index].popup = false;
        root.timeout(id);
    }

    function requestedPopupTimeout(notification) {
        if (!notification || notification.expireTimeout === 0 || notification.urgency === NotificationUrgency.Critical)
            return 0;
        return notification.expireTimeout < 0 ? root.popupTimeout : notification.expireTimeout;
    }

    function restartPopupTimer(notif) {
        if (!notif)
            return;

        if (notif.timer) {
            notif.timer.destroy();
            notif.timer = null;
        }

        const timeout = root.requestedPopupTimeout(notif.notification);
        if (timeout <= 0 || (!notif.popup && !notif.isTransient))
            return;

        notif.timer = notifTimerComponent.createObject(root, {
            "id": notif.id,
            "interval": timeout,
        });
        if (root.pausedPopupIds.has(notif.id))
            notif.timer.pause();
    }

    function pausePopupTimeout(id) {
        const notif = root.list.find(candidate => candidate.id === id) ?? null;
        if (!notif?.popup)
            return;
        root.pausedPopupIds.add(id);
        if (notif.timer)
            notif.timer.pause();
    }

    function resumePopupTimeout(id) {
        root.pausedPopupIds.delete(id);
        const notif = root.list.find(candidate => candidate.id === id) ?? null;
        if (notif?.popup && notif.timer)
            notif.timer.resume();
    }

    function handlePopupTimeout(id) {
        const notif = root.list.find(candidate => candidate.id === id) ?? null;
        if (!notif)
            return;

        notif.timer = null;
        root.pausedPopupIds.delete(id);
        if (!notif.isTransient) {
            root.timeoutNotification(id);
            return;
        }

        const source = notif.notification;
        root.removeNotifications([id], false);
        if (source)
            source.expire();
    }

    function timeoutAll() {
        root.popupList.forEach((notif) => {
            root.timeout(notif.id);
        })
        root.popupList.forEach((notif) => {
            notif.popup = false;
        });
    }

    function attemptInvokeAction(id, notifIdentifier) {
        const notifServerIndex = notifServer.trackedNotifications.values.findIndex((notif) => notif.id + root.idOffset === id);
        if (notifServerIndex !== -1) {
            const notifServerNotif = notifServer.trackedNotifications.values[notifServerIndex];
            const action = notifServerNotif.actions.find((action) => action.identifier === notifIdentifier);
            action.invoke()
        }
        else {
            console.log("Notification not found in server: " + id)
            root.discardNotification(id);
        }
    }

    function refresh() {
        notifFileView.reload()
    }

    Component.onCompleted: {
        refresh()
    }

    FileView {
        id: notifFileView
        path: Qt.resolvedUrl(filePath)
        onLoaded: {
            const fileContents = notifFileView.text()
            root.list = JSON.parse(fileContents).map((notif) => {
                return notifComponent.createObject(root, {
                    "id": notif.id,
                    "actions": [], // Notification actions are meaningless if they're not tracked by the server or the sender is dead
                    "appIcon": notif.appIcon,
                    "appName": notif.appName,
                    "body": notif.body,
                    "desktopEntry": notif.desktopEntry ?? "",
                    "image": notif.image,
                    "summary": notif.summary,
                    "time": notif.time,
                    "urgency": notif.urgency,
                });
            });
            // Find largest id
            let maxId = 0
            root.list.forEach((notif) => {
                maxId = Math.max(maxId, notif.id)
            })

            console.log("[Notifications] File loaded")
            root.idOffset = maxId
            if (root.list.length > root.maxRetained) {
                root.trimList();
                root.schedulePersist();
            }
            root.initDone()
        }
        onLoadFailed: (error) => {
            if(error == FileViewError.FileNotFound) {
                console.log("[Notifications] File not found, creating new file.")
                root.list = []
                notifFileView.setText(stringifyList(root.list));
            } else {
                console.log("[Notifications] Error loading file: " + error)
            }
        }
    }
}
