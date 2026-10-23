import QtQuick
import Quickshell.Services.UPower

QtObject {
    id: root

    readonly property var devices: UPower.devices.values
        .filter(device => device.ready && !device.powerSupply
            && device.type !== UPowerDeviceType.Unknown
            && device.type !== UPowerDeviceType.LinePower)
        .map(device => root.reading(device))

    function reading(device: var): var {
        const address = /(?:^|[^0-9a-f])((?:[0-9a-f]{2}:){5}[0-9a-f]{2})(?:$|[^0-9a-f])/i.exec(device.nativePath)
        // Quickshell does not expose BatteryLevel; UPower's qualitative icons
        // distinguish coarse levels from percentages that are safe to display.
        const match = /^battery-(full|good|low|caution|empty)(?:-|$)/.exec(device.iconName)
        const level = match ? match[1] : ""
        const available = device.isPresent && device.iconName !== "battery-missing-symbolic"
        const percentage = available && !level && Number.isFinite(device.percentage)
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
            available: available && (percentage !== null || level !== ""),
            percentage: percentage,
            level: available ? level : "",
            chargeState: device.state === UPowerDeviceState.Charging ? "charging"
                : device.state === UPowerDeviceState.FullyCharged ? "full" : "",
            connected: device.isPresent,
            connecting: false,
            connect: null
        }
    }
}
