import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import "root:/Services"
import Quickshell

QuickToggleButton {
    readonly property string hyprbarsPath: `/var/cache/hyprpm/${Quickshell.env("USER")}/hyprland-plugins/hyprbars.so`

    buttonIcon: "web_asset"
    toggled: ConfigOptions.windows.showWindowControls

    onClicked: {
        const enabled = !ConfigOptions.windows.showWindowControls;
        ConfigLoader.setConfigValueAndSave("windows.showWindowControls", enabled);
        if (enabled)
            Quickshell.execDetached(["hyprctl", "reload"]);
        else
            Quickshell.execDetached(["hyprctl", "plugin", "unload", hyprbarsPath]);
    }

    StyledToolTip {
        content: qsTr("Window controls")
    }
}
