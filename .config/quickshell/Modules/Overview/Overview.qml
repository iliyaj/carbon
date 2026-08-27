import "root:/Services"
import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false

    function virtualBoxWindowIsActive(): bool {
        const active = ToplevelManager.activeToplevel
        return /^VirtualBox/.test(active?.appId ?? "")
    }

    function toggleOverview(): void {
        if (!GlobalStates.overviewOpen && virtualBoxWindowIsActive())
            return
        GlobalStates.overviewOpen = !GlobalStates.overviewOpen
    }

    Variants {
        id: overviewVariants
        model: Quickshell.screens
        PanelWindow {
            id: root
            required property var modelData
            property string searchingText: ""
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
            screen: modelData
            visible: GlobalStates.overviewOpen

            WlrLayershell.namespace: "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            // WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            color: "transparent"

            mask: Region {
                item: GlobalStates.overviewOpen ? columnLayout : null
            }
            HyprlandWindow.visibleMask: Region {
                item: GlobalStates.overviewOpen ? columnLayout : null
            }


            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            HyprlandFocusGrab {
                id: grab
                windows: [ root ]
                property bool canBeActive: root.monitorIsFocused
                active: false
                onCleared: () => {
                    if (!active) GlobalStates.overviewOpen = false
                }
            }

            Connections {
                target: GlobalStates
                function onOverviewOpenChanged() {
                    if (!GlobalStates.overviewOpen) {
                        searchWidget.disableExpandAnimation()
                        overviewScope.dontAutoCancelSearch = false;
                    } else {
                        if (!overviewScope.dontAutoCancelSearch) {
                            searchWidget.cancelSearch()
                        }
                        delayedGrabTimer.start()
                    }
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: ConfigOptions.hacks.arbitraryRaceConditionDelay
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive) return
                    grab.active = GlobalStates.overviewOpen
                }
            }

            implicitWidth: columnLayout.implicitWidth
            implicitHeight: columnLayout.implicitHeight

            function setSearchingText(text) {
                searchWidget.setSearchingText(text);
            }

            ColumnLayout {
                id: columnLayout
                visible: GlobalStates.overviewOpen
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.overviewOpen = false;
                    } else if (event.key === Qt.Key_Left) {
                        if (!root.searchingText) Hyprland.dispatch("hl.dsp.focus({ workspace = [[r-1]] })");
                    } else if (event.key === Qt.Key_Right) {
                        if (!root.searchingText) Hyprland.dispatch("hl.dsp.focus({ workspace = [[r+1]] })");
                    }
                }

                Item {
                    implicitWidth: 1 // Prevent a zero-sized layer surface request
                    implicitHeight: 1
                }

                SearchWidget {
                    id: searchWidget
                    Layout.alignment: Qt.AlignHCenter
                    onSearchingTextChanged: (text) => {
                        root.searchingText = searchingText
                    }
                }

                Loader {
                    id: overviewLoader
                    active: GlobalStates.overviewOpen
                    sourceComponent: OverviewWidget {
                        panelWindow: root
                        visible: (root.searchingText == "")
                    }
                }
            }

        }
    }

    IpcHandler {
		target: "overview"

        function toggle() {
            overviewScope.toggleOverview()
        }
        function close() {
            GlobalStates.overviewOpen = false
        }
        function open() {
            if (!overviewScope.virtualBoxWindowIsActive())
                GlobalStates.overviewOpen = true
        }
	}

    GlobalShortcut {
        name: "overviewToggle"
        description: qsTr("Toggles overview on press")

        onPressed: {
            overviewScope.toggleOverview()
        }
    }
    GlobalShortcut {
        name: "overviewClose"
        description: qsTr("Closes overview")

        onPressed: {
            GlobalStates.overviewOpen = false
        }
    }
    GlobalShortcut {
        name: "overviewToggleRelease"
        description: qsTr("Toggles overview on release")

        onReleased: {
            // Let the compositor finish the Super-key release before changing layer contents.
            const nextState = !GlobalStates.overviewOpen
            Qt.callLater(() => {
                if (nextState && overviewScope.virtualBoxWindowIsActive())
                    return
                GlobalStates.overviewOpen = nextState
            })
        }
    }
    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: qsTr("Toggle clipboard query on overview widget")

        onPressed: {
            if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
                GlobalStates.overviewOpen = false;
                return;
            }
            if (overviewScope.virtualBoxWindowIsActive())
                return;
            for (let i = 0; i < overviewVariants.instances.length; i++) {
                let panelWindow = overviewVariants.instances[i];
                if (panelWindow.modelData.name == Hyprland.focusedMonitor.name) {
                    overviewScope.dontAutoCancelSearch = true;
                    panelWindow.setSearchingText(
                        ConfigOptions.search.prefix.clipboard
                    );
                    GlobalStates.overviewOpen = true;
                    return
                }
            }
        }
    }

}
