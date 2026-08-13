import "root:/Modules/Common/Widgets"
import "root:/Services"
import "../"

QuickToggleButton {
    buttonIcon: "coffee"
    toggled: Idle.inhibit
    onClicked: Idle.toggleInhibit()
    StyledToolTip {
        content: qsTr("Keep system awake")
    }
}
