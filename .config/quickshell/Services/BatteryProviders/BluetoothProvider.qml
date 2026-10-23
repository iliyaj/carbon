import QtQuick
import Quickshell.Bluetooth

QtObject {
    id: root

    readonly property var devices: Bluetooth.devices.values
        .filter(device => device.paired || device.batteryAvailable)
        .map(device => root.reading(device))

    function reading(device: var): var {
        const available = device.connected && device.batteryAvailable
            && Number.isFinite(device.battery) && device.battery >= 0 && device.battery <= 1
        const icons = {
            "input-mouse": "mouse",
            "input-keyboard": "keyboard",
            "input-gaming": "sports_esports",
            "audio-headset": "headset_mic",
            "audio-headphones": "headphones",
            "audio-card": "speaker",
            "phone": "smartphone"
        }
        return {
            id: device.dbusPath,
            address: device.address.toLowerCase(),
            name: device.name || qsTr("Bluetooth device"),
            icon: icons[device.icon] || "bluetooth",
            available: available,
            percentage: available ? Math.round(device.battery * 100) : null,
            level: "",
            chargeState: "",
            connected: device.connected,
            connecting: device.state === BluetoothDeviceState.Connecting,
            connect: () => device.connect()
        }
    }
}
