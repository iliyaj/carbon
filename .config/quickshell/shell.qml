//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// Adjust this to make the shell smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import "./Modules/Common/"
import "./Modules/AppImageInstaller/"
import "./Modules/BackgroundWidgets/"
import "./Modules/Bar/"
import "./Modules/Cheatsheet/"
import "./Modules/Dock/"
import "./Modules/MediaControls/"
import "./Modules/NotificationPopup/"
import "./Modules/OnScreenDisplay/"
import "./Modules/OnScreenKeyboard/"
import "./Modules/Overview/"
import "./Modules/ReloadPopup/"
import "./Modules/ScreenCorners/"
import "./Modules/Session/"
import "./Modules/SidebarLeft/"
import "./Modules/SidebarRight/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "./Services/"

// Enable or disable modules here. 
ShellRoot {
    property bool enableBar: true
    property bool enableBackgroundWidgets: true
    property bool enableCheatsheet: true
    property bool enableDock: false
    property bool enableMediaControls: true
    property bool enableNotificationPopup: true
    property bool enableOnScreenDisplayBrightness: true
    property bool enableOnScreenDisplayVolume: true
    property bool enableOnScreenKeyboard: true
    property bool enableOverview: true
    property bool enableReloadPopup: true
    property bool enableScreenCorners: true
    property bool enableSession: true
    property bool enableSidebarLeft: true
    property bool enableSidebarRight: true

    IpcHandler {
        target: "carbon"

        function ping(): void {}
    }

    function initializeNightLight(): void {
        if (PersistentStateManager.allowWriteback)
            NightLight.enabled
    }

    // Force initialization of some singletons
    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        ConfigLoader.loadConfig()
        PersistentStateManager.loadStates()
        initializeNightLight()
        Idle.inhibit
        Cliphist.refresh()
        FirstRunExperience.load()
    }

    Connections {
        target: PersistentStateManager
        function onAllowWritebackChanged(): void { initializeNightLight() }
    }

    Autolock {
        timeout: ConfigOptions.autolock.timeout
    }

    Recorder {}

    LazyLoader { active: enableBar; component: Bar {} }
    LazyLoader { active: enableBackgroundWidgets && ConfigOptions.background.showClock; component: BackgroundWidgets {} }
    LazyLoader { active: enableCheatsheet; component: Cheatsheet {} }
    LazyLoader { active: enableDock; component: Dock {} }
    LazyLoader { active: enableMediaControls; component: MediaControls {} }
    LazyLoader { active: enableNotificationPopup; component: NotificationPopup {} }
    LazyLoader { active: enableOnScreenDisplayBrightness; component: OnScreenDisplayBrightness {} }
    LazyLoader { active: enableOnScreenDisplayVolume; component: OnScreenDisplayVolume {} }
    LazyLoader { active: enableOnScreenKeyboard; component: OnScreenKeyboard {} }
    LazyLoader { active: enableOverview; component: Overview {} }
    LazyLoader { active: enableReloadPopup; component: ReloadPopup {} }
    LazyLoader { active: enableScreenCorners; component: ScreenCorners {} }
    LazyLoader { active: enableSession; component: Session {} }
    LazyLoader { active: enableSidebarLeft; component: SidebarLeft {} }
    LazyLoader { active: enableSidebarRight; component: SidebarRight {} }

    AppImageInstaller {}
}
