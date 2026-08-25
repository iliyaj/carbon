import "../"
import "root:/Services"
import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import "root:/Modules/Common/Functions"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

QuickToggleButton {
    toggled: Bluetooth.bluetoothEnabled
    buttonIcon: Bluetooth.bluetoothConnected ? "bluetooth_connected" : Bluetooth.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
    onClicked: {
        toggleBluetooth.running = true
    }
    altAction: () => {
        Quickshell.execDetached(["bash", "-c", `${ConfigOptions.apps.bluetooth}`])
        Hyprland.dispatch("hl.dsp.global([[quickshell:sidebarRightClose]])")
    }
    Process {
        id: toggleBluetooth
        command: ["bash", "-c", `bluetoothctl power ${Bluetooth.bluetoothEnabled ? "off" : "on"}`]
        onRunningChanged: {
            if(!running) {
                Bluetooth.update()
            }
        }
    }
    StyledToolTip {
        content: StringUtils.format(qsTr("{0} | Right-click to configure"),
            (Bluetooth.bluetoothEnabled && Bluetooth.bluetoothDeviceName.length > 0) ?
            Bluetooth.bluetoothDeviceName : qsTr("Bluetooth"))

    }
}
