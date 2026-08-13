//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "root:/Services/"
import "root:/Modules/Common/"
import "root:/Modules/Common/Widgets/"
import "root:/Modules/Common/Functions/color_utils.js" as ColorUtils
import "root:/Modules/Common/Functions/file_utils.js" as FileUtils
import "root:/Modules/Common/Functions/string_utils.js" as StringUtils

ApplicationWindow {
    id: root
    property string firstRunFilePath: FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: Appearance.spacing.md
    property bool showNextTime: false
    property var pages: [
        {
            name: "Style",
            icon: "palette",
            component: "Modules/Settings/StyleConfig.qml"
        },
        {
            name: "Interface",
            icon: "cards",
            component: "Modules/Settings/InterfaceConfig.qml"
        },
        {
            name: "Services",
            icon: "settings",
            component: "Modules/Settings/ServicesConfig.qml"
        },
        {
            name: "About",
            icon: "info",
            component: "Modules/Settings/About.qml"
        }
    ]
    property int currentPage: 0

    visible: true
    onClosing: Qt.quit()
    title: "illogical-impulse Settings"

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        ConfigLoader.loadConfig()
    }

    // Wide enough for the four tabs at their 160px minimum, since content only needs 606
    minimumWidth: 680
    minimumHeight: 400
    width: 700
    height: 900
    color: Appearance.m3colors.m3background

    ColumnLayout {
        // Holds the page-switching shortcuts, so it is what needs the keyboard focus
        focus: root.visible
        anchors {
            fill: parent
            margins: contentPadding
        }
        spacing: Appearance.spacing.sm

        Keys.onPressed: (event) => {
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_PageDown) {
                    root.currentPage = Math.min(root.currentPage + 1, root.pages.length - 1)
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_PageUp) {
                    root.currentPage = Math.max(root.currentPage - 1, 0)
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Tab) {
                    root.currentPage = (root.currentPage + 1) % root.pages.length;
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Backtab) {
                    root.currentPage = (root.currentPage - 1 + root.pages.length) % root.pages.length;
                    event.accepted = true;
                }
            }
        }

        Item { // Titlebar
            visible: ConfigOptions?.windows.showTitlebar
            Layout.fillWidth: true
            Layout.fillHeight: false
            implicitHeight: Math.max(titleText.implicitHeight, windowControlsRow.implicitHeight)
            StyledText {
                id: titleText
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                    leftMargin: Appearance.spacing.sm
                }
                states: State {
                    name: "leftAligned"
                    when: !ConfigOptions.windows.centerTitle
                    AnchorChanges {
                        target: titleText
                        anchors.left: titleText.parent.left
                        anchors.horizontalCenter: undefined
                    }
                }
                color: Appearance.colors.colOnLayer0
                text: "Settings"
                font.pixelSize: Appearance.font.pixelSize.title
                font.family: Appearance.font.family.title
            }
            RowLayout { // Window controls row
                id: windowControlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 35
                    implicitHeight: 35
                    onClicked: root.close()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: 20
                    }
                }
            }
        }

        PrimaryTabBar { // Page navigation
            id: tabBar
            tabButtonList: root.pages
            externalTrackedTab: root.currentPage

            function onCurrentIndexChanged(currentIndex) {
                root.currentPage = currentIndex;
            }
        }

        Item { // Window content
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: contentPadding

            Rectangle { // Content container
                anchors.fill: parent
                color: Appearance.m3colors.m3surfaceContainerLow
                radius: Appearance.rounding.normal

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    opacity: 1.0
                    source: root.pages[0].component
                    Connections {
                        target: root
                        function onCurrentPageChanged() {
                            if (pageLoader.sourceComponent !== root.pages[root.currentPage].component) {
                                switchAnim.complete();
                                switchAnim.start();
                            }
                        }
                    }

                    SequentialAnimation {
                        id: switchAnim

                        NumberAnimation {
                            target: pageLoader
                            properties: "opacity"
                            from: 1
                            to: 0
                            duration: 100
                            easing.type: Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: Appearance.animationCurves.emphasizedFirstHalf
                        }
                        PropertyAction {
                            target: pageLoader
                            property: "source"
                            value: root.pages[root.currentPage].component
                        }
                        NumberAnimation {
                            target: pageLoader
                            properties: "opacity"
                            from: 0
                            to: 1
                            duration: 200
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                        }
                    }
                }
            }
        }
    }
}
