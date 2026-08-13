import "root:/Services"
import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import "root:/Modules/Common/Functions/string_utils.js" as StringUtils
import "../"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

QuickToggleButton {
    toggled: Network.networkName.length > 0 && Network.networkName != "lo"
    buttonIcon: Network.materialSymbol
    onClicked: {
        toggleNetwork.running = true
    }
    altAction: () => {
        Quickshell.execDetached(["bash", "-c", `${Network.ethernet ? ConfigOptions.apps.networkEthernet : ConfigOptions.apps.network}`])
        Hyprland.dispatch("hl.dsp.global([[quickshell:sidebarRightClose]])")
    }
    Process {
        id: toggleNetwork
        command: ["bash", "-c", "nmcli radio wifi | grep -q enabled && nmcli radio wifi off || nmcli radio wifi on"]
        onRunningChanged: {
            if(!running) {
                Network.update()
            }
        }
    }
    StyledToolTip {
        content: StringUtils.format(qsTr("{0} | Right-click to configure"), Network.networkName)
    }
}
