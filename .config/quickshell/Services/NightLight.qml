pragma Singleton
pragma ComponentBehavior: Bound

import "root:/Modules/Common"
import "root:/Modules/Common/Functions"
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property real dayElevation: 3 // sun elevation where warming starts
    readonly property real nightElevation: -6
    readonly property int minTemperature: 1000 // hyprsunset's accepted range
    readonly property int maxTemperature: 20000

    property bool available: false
    property bool enabled: PersistentStates.nightLight.enabled
    property date now: new Date()
    property int appliedTemperature: 0
    property real lastDaemonStart: 0

    readonly property real latitude: ConfigOptions.nightLight.latitude
    readonly property real longitude: ConfigOptions.nightLight.longitude

    // 1 is full daylight, 0 is full night
    readonly property real progress: {
        if (ConfigOptions.nightLight.manualSchedule)
            return root.clockProgress()
        const altitude = SolarUtils.elevation(root.now, root.latitude, root.longitude)
        return root.clamp((altitude - root.nightElevation) / (root.dayElevation - root.nightElevation), 0, 1)
    }

    readonly property int targetTemperature: {
        const options = ConfigOptions.nightLight
        const blended = options.nightTemperature + (options.dayTemperature - options.nightTemperature) * root.progress
        return Math.round(root.clamp(blended, root.minTemperature, root.maxTemperature))
    }

    readonly property string period: root.progress >= 1
        ? qsTr("Day")
        : root.progress <= 0 ? qsTr("Night") : qsTr("Transition")

    readonly property string coordinatesText: {
        const hemisphere = (value, positive, negative) => `${Math.abs(value).toFixed(2)}° ${value < 0 ? negative : positive}`
        return `${hemisphere(root.latitude, "N", "S")}, ${hemisphere(root.longitude, "E", "W")}`
    }

    readonly property string statusText: {
        if (!root.available)
            return qsTr("hyprsunset is not running")
        if (!root.enabled)
            return qsTr("Off")
        return qsTr("%1 · %2K").arg(root.period).arg(root.targetTemperature)
    }

    readonly property string scheduleText: {
        const options = ConfigOptions.nightLight
        if (options.manualSchedule)
            return qsTr("Warms %1, clears %2")
                .arg(root.timeRange(options.sunsetTime, options.transitionMinutes).replace("-", "–"))
                .arg(root.timeRange(options.sunriseTime, options.transitionMinutes).replace("-", "–"))

        const dusk = SolarUtils.crossings(root.now, root.latitude, root.longitude, root.dayElevation)
        const dawn = SolarUtils.crossings(root.now, root.latitude, root.longitude, root.nightElevation)
        if (!dusk || !dawn)
            return qsTr("The sun never crosses the transition angles at this latitude today")

        return qsTr("Warms %1–%2, clears %3–%4")
            .arg(root.clock(dusk.setting)).arg(root.clock(dawn.setting))
            .arg(root.clock(dawn.rising)).arg(root.clock(dusk.rising))
    }

    function clamp(value: real, low: real, high: real): real {
        return Math.max(low, Math.min(high, value))
    }

    function clock(date: date): string {
        return Qt.formatTime(date, "HH:mm")
    }

    function minutesOfDay(text: string): int {
        const parts = String(text).split(":")
        return (((parseInt(parts[0]) || 0) * 60 + (parseInt(parts[1]) || 0)) % 1440 + 1440) % 1440
    }

    function timeRange(start: string, minutes: int): string {
        const from = root.minutesOfDay(start)
        const to = (from + Math.max(1, minutes)) % 1440
        const format = value => `${String(Math.floor(value / 60)).padStart(2, "0")}:${String(value % 60).padStart(2, "0")}`
        return `${format(from)}-${format(to)}`
    }

    function clockProgress(): real {
        const options = ConfigOptions.nightLight
        const span = Math.max(1, options.transitionMinutes)
        const minutes = root.now.getHours() * 60 + root.now.getMinutes()
        const dawn = root.minutesOfDay(options.sunriseTime)
        const dusk = root.minutesOfDay(options.sunsetTime)
        const since = from => (minutes - from + 1440) % 1440

        if (since(dawn) < span)
            return since(dawn) / span
        if (since(dusk) < span)
            return 1 - since(dusk) / span
        return since(dawn) < since(dusk) ? 1 : 0
    }

    function setEnabled(value: bool): void {
        root.enabled = value
        PersistentStateManager.setState("nightLight.enabled", value)
        root.apply()
    }

    function toggle(): void {
        root.setEnabled(!root.enabled)
    }

    function apply(): void {
        if (!root.available)
            return
        if (!root.enabled) {
            root.appliedTemperature = 0
            Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"])
            return
        }
        if (root.appliedTemperature === root.targetTemperature)
            return

        root.appliedTemperature = root.targetTemperature
        Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(root.targetTemperature)])
    }

    function refresh(): void {
        root.now = new Date()
        if (!probeProcess.running)
            probeProcess.running = true
    }

    function startDaemon(): void {
        const stamp = Date.now()
        if (stamp - root.lastDaemonStart < 20000)
            return

        root.lastDaemonStart = stamp
        Quickshell.execDetached(["hyprsunset"])
    }

    onTargetTemperatureChanged: root.apply()
    onAvailableChanged: {
        root.appliedTemperature = 0
        root.apply()
    }

    Component.onCompleted: root.refresh()

    Process {
        id: probeProcess
        command: ["hyprctl", "hyprsunset", "temperature"]
        onExited: (exitCode, exitStatus) => {
            root.available = exitCode === 0
            if (exitCode !== 0)
                root.startDaemon()
        }
    }

    Timer {
        // transitions move fast enough to need frequent steps, daylight and night do not
        interval: (root.progress > 0 && root.progress < 1) ? 20000 : 120000
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }
}
