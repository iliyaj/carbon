pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
    id: root

    readonly property string configPath: "/etc/logid.cfg"
    readonly property string imageSource: "root:/Assets/Images/mx-master-3-wireframe.webp"
    readonly property var batteryDevice: DeviceBatteries.devices.find(device =>
        device.name.toLowerCase().includes("mx master 3")) ?? null
    readonly property bool batteryAvailable: batteryDevice?.available ?? false
    readonly property bool batteryLow: DeviceBatteries.isLow(batteryDevice)
    readonly property string batteryText: batteryAvailable
        ? qsTr("Battery: %1").arg(DeviceBatteries.levelText(batteryDevice)) : qsTr("Battery unavailable")
    readonly property string batteryMaterialIcon: DeviceBatteries.batteryIcon(batteryDevice)

    property bool daemonRunning: false
    property bool configAvailable: false
    readonly property string modelName: "MX Master 3"
    property string deviceName: "MX Master 3"
    property bool thumbwheelDiverted: false
    property bool thumbwheelInverted: false
    property string thumbwheelLeftAction: ""
    property string thumbwheelRightAction: ""
    property string forwardButtonAction: ""
    property string backButtonAction: ""
    property string gestureButtonAction: ""
    property var buttonBindings: []

    readonly property bool ready: root.configAvailable && root.daemonRunning
    readonly property string statusText: !root.configAvailable
        ? qsTr("Configuration unavailable")
        : root.daemonRunning ? qsTr("Configuration active") : qsTr("Configuration found · service stopped")

    function capture(text: string, expression: var, fallback: string): string {
        const match = text.match(expression)
        return match ? match[1].trim() : fallback
    }

    function actionForCid(text: string, cid: string): string {
        const expression = new RegExp("cid\\s*[:=]\\s*" + cid
            + "[\\s\\S]*?keys\\s*[:=]\\s*\\[([^\\]]+)\\]", "i")
        const keys = root.capture(text, expression, "")
        return keys.replace(/[\"']/g, "").replace(/KEY_/g, "").replace(/,\s*/g, " + ")
    }

    function parseConfig(text: string): void {
        root.configAvailable = text.length > 0 && /devices\s*:/i.test(text)
        if (!root.configAvailable)
            return

        root.deviceName = root.capture(text, /name\s*:\s*"([^"]+)"/i, "MX Master 3")
        root.thumbwheelDiverted = root.capture(text, /thumbwheel\s*:\s*\{[\s\S]*?divert\s*:\s*(true|false)/i, "false") === "true"
        root.thumbwheelInverted = root.capture(text, /thumbwheel\s*:\s*\{[\s\S]*?invert\s*:\s*(true|false)/i, "false") === "true"
        root.thumbwheelLeftAction = root.capture(text, /thumbwheel\s*:\s*\{[\s\S]*?left\s*:\s*\{[\s\S]*?keys\s*:\s*\[([^\]]+)\]/i, "").replace(/[\"']/g, "").replace(/KEY_/g, "")
        root.thumbwheelRightAction = root.capture(text, /thumbwheel\s*:\s*\{[\s\S]*?right\s*:\s*\{[\s\S]*?keys\s*:\s*\[([^\]]+)\]/i, "").replace(/[\"']/g, "").replace(/KEY_/g, "")
        root.forwardButtonAction = root.actionForCid(text, "0x56")
        root.backButtonAction = root.actionForCid(text, "0x53")
        root.gestureButtonAction = root.actionForCid(text, "0xc3")
        root.buttonBindings = [
            { label: qsTr("Wheel click"), action: root.actionForCid(text, "0x0052") },
            { label: qsTr("Forward"), action: root.forwardButtonAction },
            { label: qsTr("Back"), action: root.backButtonAction },
            { label: qsTr("Gesture"), action: root.gestureButtonAction }
        ].filter(binding => binding.action.length > 0)
    }

    function refresh(): void {
        if (!daemonProbe.running)
            daemonProbe.running = true
    }

    Component.onCompleted: root.refresh()

    FileView {
        id: configFile
        path: root.configPath
        preload: true
        onLoaded: root.parseConfig(text())
        onFileChanged: reload()
        onLoadFailed: root.configAvailable = false
    }

    Process {
        id: daemonProbe
        command: ["systemctl", "is-active", "--quiet", "logid.service"]
        onExited: (exitCode, exitStatus) => root.daemonRunning = exitCode === 0
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: {
            if (!daemonProbe.running)
                daemonProbe.running = true
        }
    }
}
