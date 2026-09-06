import qs.Modules.Common
import qs.Modules.Common.Widgets
import qs.Services
import "../"
import Quickshell

QuickToggleButton {
    toggled: NightLight.enabled
    buttonIcon: "nightlight"
    enabled: NightLight.available
    onClicked: NightLight.toggle()

    StyledToolTip {
        content: NightLight.available
            ? qsTr("Night Light · %1\n%2").arg(NightLight.statusText).arg(NightLight.scheduleText)
            : qsTr("Night Light")
    }
}
