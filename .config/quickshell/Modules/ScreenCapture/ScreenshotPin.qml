pragma ComponentBehavior: Bound

import qs.Modules.Common
import qs.Services
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs as NativeDialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var modelData
    readonly property string path: modelData.path
    readonly property bool ready: image.status === Image.Ready && image.implicitWidth > 0 && image.implicitHeight > 0
    property bool closing: false
    property int quarter: 0
    property real zoom: 0
    property real posX: 0
    property real posY: 0
    property real pinOpacity: 1
    property bool smoothScaling: ConfigOptions.screenshot.pinSmoothing
    readonly property bool saveDialogOpen: saveDialog.visible
    property point dragOrigin
    readonly property bool turned: quarter % 2 === 1
    readonly property real baseWidth: turned ? image.implicitHeight : image.implicitWidth
    readonly property real baseHeight: turned ? image.implicitWidth : image.implicitHeight
    readonly property real screenWidth: screen.width
    readonly property real screenHeight: screen.height
    readonly property real minZoom: Math.min(1, 64 / Math.max(image.implicitWidth, image.implicitHeight, 1))
    readonly property real maxZoom: Math.max(minZoom, Math.min(8, screenWidth / Math.max(baseWidth, 1), screenHeight / Math.max(baseHeight, 1)))
    readonly property real fitZoom: clampZoom(Math.min(1, 0.8 * screenWidth / Math.max(baseWidth, 1), 0.8 * screenHeight / Math.max(baseHeight, 1)))

    screen: Quickshell.screens.find(s => s.name === modelData.screen) ?? Quickshell.screens[0] ?? null
    visible: ready && zoom > 0 && !closing
    color: "transparent"
    readonly property real pinWidth: Math.max(1, Math.round(baseWidth * zoom))
    readonly property real pinHeight: Math.max(1, Math.round(baseHeight * zoom))
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    // Moving a layer surface changes its pointer coordinates; keep the surface fixed.
    mask: Region { item: content }
    WlrLayershell.layer: ScreenPins.dialogOpen ? WlrLayer.Bottom : WlrLayer.Top // keep its dialog unobscured
    WlrLayershell.namespace: "quickshell:screenCapture"
    WlrLayershell.keyboardFocus: focusTimer.armed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None // Hyprland focuses OnDemand layers on map

    onReadyChanged: {
        if (!ready || zoom > 0) return;
        zoom = fitZoom;
        posX = (screenWidth - baseWidth * zoom) / 2 + modelData.cascade * 32;
        posY = (screenHeight - baseHeight * zoom) / 2 + modelData.cascade * 32;
        clampPosition();
    }

    function clampZoom(value): real {
        return Math.max(minZoom, Math.min(maxZoom, value));
    }

    function clampPosition(): void {
        posX = Math.max(0, Math.min(screenWidth - pinWidth, posX));
        posY = Math.max(0, Math.min(screenHeight - pinHeight, posY));
    }

    function setZoom(value, anchorX, anchorY): void {
        const next = clampZoom(value);
        const ratio = next / zoom;
        posX += anchorX * (1 - ratio);
        posY += anchorY * (1 - ratio);
        zoom = next;
        clampPosition();
    }

    function resetSize(): void {
        setZoom(fitZoom, pinWidth / 2, pinHeight / 2);
    }

    function rotate(step): void {
        const centerX = posX + pinWidth / 2;
        const centerY = posY + pinHeight / 2;
        quarter = (quarter + step + 4) % 4;
        zoom = clampZoom(zoom);
        posX = centerX - baseWidth * zoom / 2;
        posY = centerY - baseHeight * zoom / 2;
        clampPosition();
    }

    function setOpacity(value): void {
        pinOpacity = Math.round(Math.max(0.1, Math.min(1, value)) * 10) / 10;
    }

    function exportImage(action, destination, options): void {
        if (output.busy || closing) return;
        output.perform(path, action, destination, Object.assign({ rotation: quarter * 90 }, options));
    }

    function copyImage(): void {
        exportImage("copy", "", { clipboardFormat: "png" });
    }

    function saveImage(): void {
        const folder = decodeURIComponent(Directories.pictures.toString().replace(/^file:\/\//, "")) + "/Screenshots";
        exportImage("save", `${folder}/Screenshot_${Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH.mm.ss.zzz")}.png`, { format: "png" });
    }

    function saveAs(): void {
        if (output.busy || closing) return;
        const folder = Directories.pictures.toString() + "/Screenshots";
        saveDialog.currentFolder = folder;
        saveDialog.open();
    }

    function cancelOutput(): void {
        output.cancel();
    }

    function closePin(): void {
        if (closing) return;
        closing = true;
        menu.close();
        if (!output.busy) Qt.callLater(ScreenPins.release, path); // finish an in-flight copy/save first
    }

    Item {
        id: content
        x: root.posX
        y: root.posY
        width: root.pinWidth
        height: root.pinHeight
        opacity: root.pinOpacity
        focus: true
        Keys.onPressed: event => {
            const control = event.modifiers & Qt.ControlModifier;
            event.accepted = true;
            if (event.key === Qt.Key_Escape || (control && event.key === Qt.Key_Q)) root.closePin();
            else if (control && event.key === Qt.Key_C) root.copyImage();
            else if (control && event.key === Qt.Key_S) root.saveAs();
            else if (control && event.key === Qt.Key_R) root.rotate(-1);
            else if (control && event.key === Qt.Key_0) root.resetSize();
            else if (event.key === Qt.Key_R) root.rotate(1);
            else if (event.key === Qt.Key_Up) root.setOpacity(root.pinOpacity + 0.1);
            else if (event.key === Qt.Key_Down) root.setOpacity(root.pinOpacity - 0.1);
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) root.setOpacity((event.key - Qt.Key_0) / 10);
            else if (event.key === Qt.Key_0) root.setOpacity(1);
            else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) root.setZoom(root.zoom * 1.25, root.pinWidth / 2, root.pinHeight / 2);
            else if (event.key === Qt.Key_Minus) root.setZoom(root.zoom / 1.25, root.pinWidth / 2, root.pinHeight / 2);
            else if (event.key === Qt.Key_Menu) menu.popup(content, root.pinWidth / 2, root.pinHeight / 2);
            else event.accepted = false;
        }

        Image {
            id: image
            anchors.centerIn: parent
            width: root.turned ? parent.height : parent.width
            height: root.turned ? parent.width : parent.height
            rotation: root.quarter * 90
            source: "file://" + root.path.split("/").map(encodeURIComponent).join("/")
            asynchronous: true
            cache: false
            autoTransform: false
            smooth: root.smoothScaling
            mipmap: root.smoothScaling
            onStatusChanged: {
                if (status !== Image.Error) return;
                Quickshell.execDetached(["notify-send", "-a", "Screen clipping", "Screenshot pin failed", qsTr("Could not load the pinned image.")]);
                root.closePin();
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: content.activeFocus ? Appearance.colors.colPrimary : "#80000000"
        }

        DragHandler {
            target: null
            acceptedButtons: Qt.LeftButton
            onActiveChanged: if (active) root.dragOrigin = Qt.point(root.posX, root.posY)
            onActiveTranslationChanged: {
                if (!active) return;
                root.posX = root.dragOrigin.x + activeTranslation.x;
                root.posY = root.dragOrigin.y + activeTranslation.y;
                root.clampPosition();
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: mouse => {
                if (mouse.button === Qt.RightButton) {
                    menu.popup(content, mouse.x, mouse.y);
                    return;
                }
            }
            onDoubleClicked: mouse => {
                if (mouse.button === Qt.LeftButton) root.resetSize();
            }
            onWheel: wheel => root.setZoom(root.zoom * Math.pow(1.1, wheel.angleDelta.y / 120), wheel.x, wheel.y)
        }
    }

    Timer {
        id: focusTimer
        property bool armed: false
        interval: 250
        running: root.visible && !armed
        onTriggered: armed = true
    }

    ScreenshotOutput {
        id: output
        originalPath: root.modelData.original
        onFinished: if (root.closing) ScreenPins.release(root.path)
        onFailed: message => {
            Quickshell.execDetached(["notify-send", "-a", "Screen clipping", "Screenshot pin export failed", message]);
            if (root.closing) ScreenPins.release(root.path);
        }
    }

    NativeDialogs.FileDialog {
        id: saveDialog
        title: qsTr("Save pinned screenshot as")
        fileMode: NativeDialogs.FileDialog.SaveFile
        nameFilters: ScreenPins.formats.map(f => f.label + " (" + f.extensions.map(e => "*." + e).join(" ") + ")")
        defaultSuffix: ScreenPins.formats[selectedNameFilter.index]?.extensions[0] ?? "png"
        onAccepted: {
            const destination = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""));
            root.exportImage("save", destination, { format: ScreenPins.formats[selectedNameFilter.index]?.id ?? "png", overwrite: true }); // dialog confirmed replacement
        }
    }

    Menu {
        id: menu
        popupType: Popup.Window

        PinMenuItem { text: qsTr("Copy image"); shortcut: "Ctrl+C"; enabled: !output.busy; onTriggered: root.copyImage() }
        PinMenuItem { text: qsTr("Save"); enabled: !output.busy; onTriggered: root.saveImage() }
        PinMenuItem { text: qsTr("Save as…"); shortcut: "Ctrl+S"; enabled: !output.busy; onTriggered: root.saveAs() }
        MenuSeparator {}
        PinMenuItem { text: qsTr("Rotate right"); shortcut: "R"; onTriggered: root.rotate(1) }
        PinMenuItem { text: qsTr("Rotate left"); shortcut: "Ctrl+R"; onTriggered: root.rotate(-1) }
        PinMenuItem { text: qsTr("Zoom in"); shortcut: "+ / Wheel"; onTriggered: root.setZoom(root.zoom * 1.25, root.pinWidth / 2, root.pinHeight / 2) }
        PinMenuItem { text: qsTr("Zoom out"); shortcut: "− / Wheel"; onTriggered: root.setZoom(root.zoom / 1.25, root.pinWidth / 2, root.pinHeight / 2) }
        PinMenuItem { text: qsTr("Reset size"); shortcut: "Ctrl+0 / Double-click"; onTriggered: root.resetSize() }
        PinMenuItem { text: qsTr("Smooth scaling"); checkable: true; checked: root.smoothScaling; onTriggered: root.smoothScaling = checked }
        MenuSeparator {}
        PinMenuItem { text: qsTr("Increase opacity"); shortcut: "↑"; enabled: root.pinOpacity < 1; onTriggered: root.setOpacity(root.pinOpacity + 0.1) }
        PinMenuItem { text: qsTr("Decrease opacity"); shortcut: "↓ / 1–9"; enabled: root.pinOpacity > 0.1; onTriggered: root.setOpacity(root.pinOpacity - 0.1) }
        MenuSeparator {}
        PinMenuItem { text: qsTr("Close"); shortcut: "Esc"; onTriggered: root.closePin() }
    }

    component PinMenuItem: MenuItem {
        id: item
        property string shortcut: ""
        contentItem: RowLayout {
            spacing: 24
            Label {
                Layout.fillWidth: true
                leftPadding: item.checkable && item.indicator ? item.indicator.width + item.spacing : 0
                text: item.text
                color: item.palette.windowText
                opacity: item.enabled ? 1 : 0.5
            }
            Label {
                text: item.shortcut
                color: item.palette.windowText
                opacity: 0.6
            }
        }
    }
}
