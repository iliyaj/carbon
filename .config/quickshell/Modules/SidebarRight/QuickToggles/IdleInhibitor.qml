import qs.Modules.Common.Widgets
import qs.Services
import "../"

QuickToggleButton {
    buttonIcon: "coffee"
    toggled: Idle.inhibit
    onClicked: Idle.toggleInhibit()
    StyledToolTip {
        content: qsTr("Keep system awake")
    }
}
