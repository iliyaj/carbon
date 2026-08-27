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
    property bool enabled: false
    property date now: new Date()
    property int appliedTemperature: 0
    property real lastDaemonStart: 0

    property string timezone: ""
    property real timezoneLatitude: NaN
    property real timezoneLongitude: NaN

    readonly property bool timezoneLocated: !isNaN(root.timezoneLatitude) && !isNaN(root.timezoneLongitude)
    readonly property bool usingSystemLocation: ConfigOptions.nightLight.systemLocation && root.timezoneLocated

    readonly property real latitude: root.usingSystemLocation ? root.timezoneLatitude : ConfigOptions.nightLight.latitude
    readonly property real longitude: root.usingSystemLocation ? root.timezoneLongitude : ConfigOptions.nightLight.longitude

    readonly property string locationText: {
        if (root.usingSystemLocation)
            return qsTr("%1 · %2").arg(root.timezone).arg(root.coordinatesText)
        if (ConfigOptions.nightLight.systemLocation)
            return qsTr("No coordinates for this timezone, using the values below")
        return qsTr("Sunset schedule computed for %1").arg(root.coordinatesText)
    }

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

    // tzdata gives each zone a representative city in ISO 6709, as +DDMM+DDDMM or +DDMMSS+DDDMMSS
    function handleTimezone(line: string): void {
        const parts = line.split("|")
        root.timezone = parts[0] ?? ""

        const match = (parts[1] ?? "").match(/^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$/)
        if (!match) {
            root.timezoneLatitude = NaN
            root.timezoneLongitude = NaN
            return
        }

        const degrees = (sign, d, m, s) => (sign === "-" ? -1 : 1) * (Number(d) + Number(m) / 60 + Number(s ?? 0) / 3600)
        root.timezoneLatitude = degrees(match[1], match[2], match[3], match[4])
        root.timezoneLongitude = degrees(match[5], match[6], match[7], match[8])
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

    // assigning `enabled` would break a plain binding, so follow the shared state by hand
    function syncEnabled(): void {
        if (root.enabled !== PersistentStates.nightLight.enabled)
            root.enabled = PersistentStates.nightLight.enabled
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
        if (!timezoneProcess.running)
            timezoneProcess.running = true
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

    Component.onCompleted: {
        root.enabled = PersistentStates.nightLight.enabled
        root.refresh()
    }

    Connections {
        target: PersistentStates.nightLight
        function onEnabledChanged() { root.syncEnabled() }
    }

    Process {
        id: timezoneProcess
        command: ["bash", "-c",
            "tz=$(readlink -f /etc/localtime | sed 's|.*/zoneinfo/||');"
            + " echo \"$tz|$(awk -F'\t' -v z=\"$tz\" '$0 !~ /^#/ && $3 == z {print $2; exit}'"
            + " /usr/share/zoneinfo/zone1970.tab /usr/share/zoneinfo/zone.tab 2>/dev/null)\""]
        stdout: SplitParser {
            onRead: data => root.handleTimezone(data)
        }
    }

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
