import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import "root:/Services"
import QtQuick
import Quickshell

QuickToggleButton {
    id: root
    readonly property string hyprbarsPath: `/var/cache/hyprpm/${Quickshell.env("USER")}/hyprland-plugins/hyprbars.so`

    buttonIcon: "web_asset"
    toggled: ConfigOptions.windows.showWindowControls

    onClicked: {
        const enabled = !ConfigOptions.windows.showWindowControls;
        ConfigLoader.setConfigValueAndSave("windows.showWindowControls", enabled);
        applyTimer.restart(); // keep the compositor work off the click
    }

    Timer {
        id: applyTimer
        interval: 200
        onTriggered: {
            ConfigLoader.flushConfig(); // reload re-reads config.json
            if (ConfigOptions.windows.showWindowControls)
                Quickshell.execDetached(["hyprctl", "reload"]);
            else
                Quickshell.execDetached(["hyprctl", "plugin", "unload", root.hyprbarsPath]);
        }
    }

    StyledToolTip {
        content: qsTr("Window controls")
    }
}
