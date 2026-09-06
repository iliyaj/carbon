import qs.Services
import qs.Modules.Common.Widgets

QuickToggleButton {
    buttonIcon: "gamepad"
    toggled: GlobalStates.gameMode

    onClicked: GlobalStates.setGameMode(!GlobalStates.gameMode)

    StyledToolTip {
        content: qsTr("Game mode")
    }
}
