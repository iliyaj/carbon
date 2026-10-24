pragma Singleton

import Quickshell
import qs.Services.BatteryProviders

Singleton {
    id: root

    // Providers own readings and connection actions; this service owns the
    // combined list and presentation shared by the sidebar and device pages.
    readonly property var devices: mergeDevices(upowerProvider.devices, bluetoothProvider.devices)

    UPowerProvider { id: upowerProvider }
    BluetoothProvider { id: bluetoothProvider }

    function mergeDevices(upower: var, bluetooth: var): var {
        const remaining = upower.slice()
        const combined = bluetooth.map(device => {
            // HID batteries (for example DualSense) use a kernel path containing
            // the Bluetooth address instead of the BlueZ object path.
            const index = remaining.findIndex(other => other.id === device.id
                || (device.address !== "" && other.address === device.address))
            if (index === -1)
                return device
            const other = remaining.splice(index, 1)[0]
            const reading = device.available ? device : other
            return Object.assign({}, reading, {
                id: device.id,
                name: device.name,
                icon: other.icon === "battery_full" ? device.icon : other.icon,
                available: device.connected && reading.available,
                percentage: device.connected ? reading.percentage : null,
                level: device.connected ? reading.level : "",
                chargeState: device.connected ? reading.chargeState : "",
                connected: device.connected,
                connecting: device.connecting,
                connect: device.connect
            })
        })
        return remaining.concat(combined).sort((left, right) => left.name.localeCompare(right.name))
    }

    readonly property var levelPercentages: ({ critical: 5, low: 20, normal: 50, high: 70, full: 100 }) // mx master 3 steps

    function percentageOf(device: var): var {
        return device?.available ? device.percentage ?? root.levelPercentages[device.level] ?? null : null
    }

    function levelText(device: var): string {
        const percentage = percentageOf(device)
        if (percentage === null)
            return qsTr("Unavailable")
        return (device.percentage === null ? qsTr("~%1%") : qsTr("%1%")).arg(percentage)
    }

    function statusText(device: var): string {
        if (device?.connecting)
            return qsTr("Connecting…")
        if (!device?.connected)
            return qsTr("Disconnected")
        if (!device.available)
            return qsTr("Battery unavailable")
        if (device.chargeState === "charging")
            return qsTr("Charging")
        if (device.chargeState === "full")
            return qsTr("Fully charged")
        return qsTr("Connected")
    }

    function isLow(device: var): bool {
        const percentage = percentageOf(device)
        return percentage !== null && percentage <= 20
    }

    function batteryIcon(device: var): string {
        const percentage = percentageOf(device)
        if (percentage === null)
            return "battery_unknown"
        if (device.chargeState === "charging")
            return "battery_charging_full"
        if (percentage <= 5)
            return "battery_alert"
        if (percentage >= 95)
            return "battery_full"
        return "battery_" + Math.min(6, Math.floor(percentage / 15)) + "_bar"
    }
}
