pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Scope {
    id: root

    readonly property var devices: supplies.instances.map(supply => supply.reading)

    Variants {
        id: supplies
        model: UPower.devices.values
            .filter(device => device.ready && !device.powerSupply
                && device.type !== UPowerDeviceType.Unknown
                && device.type !== UPowerDeviceType.LinePower)

        QtObject {
            id: supply
            required property UPowerDevice modelData
            readonly property bool kernel: !modelData.nativePath.includes("/") // bluez paths have no sysfs node
            readonly property FileView uevent: FileView {
                path: supply.kernel ? `/sys/class/power_supply/${supply.modelData.nativePath}/uevent` : ""
                printErrors: false
            }
            readonly property var reading: root.reading(modelData, kernel ? uevent.text() : null)
            readonly property Connections refresh: Connections {
                target: supply.modelData
                function onPercentageChanged() { supply.uevent.reload() } // upower synthesises one per level
            }
        }
    }

    function reading(device: var, uevent: var): var {
        const address = /(?:^|[^0-9a-f])((?:[0-9a-f]{2}:){5}[0-9a-f]{2})(?:$|[^0-9a-f])/i.exec(device.nativePath)
        const available = device.isPresent && device.iconName !== "battery-missing-symbolic"
        const precise = uevent === null || /^POWER_SUPPLY_CAPACITY=[1-9]/m.test(uevent) // upower's level rule
        const match = /^POWER_SUPPLY_CAPACITY_LEVEL=(Critical|Low|Normal|High|Full)$/m.exec(uevent ?? "")
        const level = available && !precise && match ? match[1].toLowerCase() : ""
        const percentage = available && precise && Number.isFinite(device.percentage)
            && device.percentage >= 0 && device.percentage <= 1
            ? Math.round(device.percentage * 100) : null
        const icons = {
            [UPowerDeviceType.Mouse]: "mouse",
            [UPowerDeviceType.Keyboard]: "keyboard",
            [UPowerDeviceType.Phone]: "smartphone",
            [UPowerDeviceType.Tablet]: "tablet",
            [UPowerDeviceType.GamingInput]: "sports_esports",
            [UPowerDeviceType.Headset]: "headset_mic",
            [UPowerDeviceType.Headphones]: "headphones",
            [UPowerDeviceType.Speakers]: "speaker",
            [UPowerDeviceType.Wearable]: "watch"
        }
        return {
            id: device.nativePath,
            address: address ? address[1].toLowerCase() : "",
            name: device.model || qsTr("Battery device"),
            icon: icons[device.type] || "battery_full",
            available: percentage !== null || level !== "",
            percentage: percentage,
            level: level,
            chargeState: device.state === UPowerDeviceState.Charging ? "charging"
                : device.state === UPowerDeviceState.FullyCharged ? "full" : "",
            connected: device.isPresent,
            connecting: false,
            connect: null
        }
    }
}
