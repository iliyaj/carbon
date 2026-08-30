import "root:/Services/"
import "root:/Modules/Common/"
import "root:/Modules/Common/Widgets"
import "root:/Modules/Common/Functions"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower

Scope {
    id: bar

    readonly property int barHeight: Appearance.sizes.barHeight
    readonly property int sidebarButtonIconSize: Appearance.font.pixelSize.huge
    // Fixed so both sidebar buttons match, since their glyphs have different advance widths
    readonly property int sidebarButtonWidth: sidebarButtonIconSize + 10 * 2
    property bool showBarBackground: ConfigOptions.bar.showBackground

    component VerticalBarSeparator: Rectangle {
        Layout.topMargin: barHeight / 3
        Layout.bottomMargin: barHeight / 3
        Layout.fillHeight: true
        implicitWidth: 1
        color: Appearance.colors.colOutlineVariant
    }

    Variants { // For each monitor
        model: {
            const screens = Quickshell.screens;
            const list = ConfigOptions.bar.screenList;
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }

        PanelWindow { // Bar window
            id: barRoot
            screen: modelData

            property ShellScreen modelData
            property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen.width) ? 2 :
                (Appearance.sizes.barShortenScreenWidthThreshold >= screen.width) ? 1 : 0
            readonly property int configuredCenterSideModuleWidth:
                (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened :
                (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened :
                    Appearance.sizes.barCenterSideModuleWidth
            // Keep both sides equal while allowing enabled utilities to reserve their natural width
            readonly property int centerSideModuleWidth: Math.max(configuredCenterSideModuleWidth,
                Math.ceil(rightCenterGroupContent.implicitWidth))

            WlrLayershell.namespace: "quickshell:bar"
            implicitHeight: barHeight + (GlobalStates.gameMode ? 0 : Appearance.rounding.screenRounding)
            exclusiveZone: showBarBackground ? barHeight : (barHeight - 4)
            mask: Region {
                item: barContent
            }
            color: "transparent"

            anchors {
                top: !ConfigOptions.bar.bottom
                bottom: ConfigOptions.bar.bottom
                left: true
                right: true
            }

            Rectangle { // Bar background
                id: barContent
                anchors {
                    right: parent.right
                    left: parent.left
                    top: !ConfigOptions.bar.bottom ? parent.top : undefined
                    bottom: ConfigOptions.bar.bottom ? parent.bottom : undefined
                }
                color: showBarBackground ? Appearance.colors.colLayer0 : "transparent"
                height: barHeight

                MouseArea { // Left side
                    id: barLeftSideMouseArea
                    anchors.left: parent.left
                    implicitHeight: barHeight
                    width: (barRoot.width - middleSection.width) / 2
                    property bool hovered: false
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onEntered: (event) => {
                        barLeftSideMouseArea.hovered = true
                    }
                    onExited: (event) => {
                        barLeftSideMouseArea.hovered = false
                    }
                    Item {  // Left section
                        anchors.fill: parent
                        implicitHeight: leftSectionRowLayout.implicitHeight
                        implicitWidth: leftSectionRowLayout.implicitWidth

                        RowLayout { // Content
                            id: leftSectionRowLayout
                            anchors.fill: parent
                            spacing: 10

                            RippleButton { // Left sidebar button
                                id: leftSidebarButton
                                Layout.margins: 4
                                Layout.leftMargin: Appearance.spacing.xs
                                Layout.fillWidth: false
                                Layout.fillHeight: true
                                implicitWidth: bar.sidebarButtonWidth
                                buttonRadius: Appearance.rounding.full
                                colBackground: barLeftSideMouseArea.hovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                colRipple: Appearance.colors.colLayer1Active
                                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                                toggled: GlobalStates.sidebarLeftOpen
                                property color colText: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0

                                Behavior on colText {
                                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                }

                                onPressed: {
                                    Hyprland.dispatch("hl.dsp.global([[quickshell:sidebarLeftToggle]])")
                                }

                                MaterialSymbol {
                                    id: leftSidebarIcon
                                    anchors.centerIn: parent
                                    text: "apps"
                                    iconSize: bar.sidebarButtonIconSize
                                    color: leftSidebarButton.colText
                                }
                            }

                            ActiveWindow {
                                visible: barRoot.useShortenedForm === 0
                                Layout.rightMargin: Appearance.rounding.screenRounding
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                bar: barRoot
                            }
                        }
                    }
                }

                RowLayout { // Middle section
                    id: middleSection
                    anchors.centerIn: parent
                    spacing: ConfigOptions?.bar.borderless ? 4 : 8

                    BarGroup {
                        id: leftCenterGroup
                        Layout.preferredWidth: barRoot.centerSideModuleWidth
                        Layout.fillHeight: true

                        Resources {
                            Layout.fillWidth: barRoot.useShortenedForm === 2
                        }

                        Media {
                            visible: barRoot.useShortenedForm < 2
                            Layout.fillWidth: true
                        }

                    }

                    VerticalBarSeparator {visible: ConfigOptions?.bar.borderless}

                    BarGroup {
                        id: middleCenterGroup
                        padding: workspacesWidget.widgetPadding
                        Layout.fillHeight: true

                        Workspaces {
                            id: workspacesWidget
                            bar: barRoot
                            Layout.fillHeight: true
                            MouseArea { // Right-click to toggle overview
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton

                                onPressed: (event) => {
                                    if (event.button === Qt.RightButton) {
                                        Hyprland.dispatch("hl.dsp.global([[quickshell:overviewToggle]])")
                                    }
                                }
                            }
                        }
                    }

                    VerticalBarSeparator {visible: ConfigOptions?.bar.borderless}

                    MouseArea {
                        id: rightCenterGroup
                        implicitWidth: rightCenterGroupContent.implicitWidth
                        implicitHeight: rightCenterGroupContent.implicitHeight
                        Layout.preferredWidth: barRoot.centerSideModuleWidth
                        Layout.fillHeight: true

                        onPressed: {
                            Hyprland.dispatch("hl.dsp.global([[quickshell:sidebarRightToggle]])")
                        }

                        BarGroup {
                            id: rightCenterGroupContent
                            anchors.fill: parent

                            ClockWidget {
                                visible: ConfigOptions.bar.showClock
                                showDate: (ConfigOptions.bar.verbose && barRoot.useShortenedForm < 2)
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                            }

                            UtilButtons {
                                visible: (ConfigOptions.bar.verbose && barRoot.useShortenedForm === 0)
                                Layout.alignment: Qt.AlignVCenter
                            }

                            BatteryIndicator {
                                visible: (barRoot.useShortenedForm < 2 && UPower.displayDevice.isLaptopBattery)
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                }

                MouseArea { // Right side
                    id: barRightSideMouseArea

                    anchors.right: parent.right
                    implicitHeight: barHeight
                    width: (barRoot.width - middleSection.width) / 2

                    property bool hovered: false

                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onEntered: (event) => {
                        barRightSideMouseArea.hovered = true
                    }
                    onExited: (event) => {
                        barRightSideMouseArea.hovered = false
                    }

                    Item {
                        anchors.fill: parent
                        implicitHeight: rightSectionRowLayout.implicitHeight
                        implicitWidth: rightSectionRowLayout.implicitWidth

                        RowLayout {
                            id: rightSectionRowLayout
                            anchors.fill: parent
                            spacing: 5
                            layoutDirection: Qt.RightToLeft

                            RippleButton { // Right sidebar button
                                id: rightSidebarButton
                                Layout.margins: 4
                                Layout.rightMargin: Appearance.spacing.xs
                                Layout.fillHeight: true
                                implicitWidth: bar.sidebarButtonWidth
                                buttonRadius: Appearance.rounding.full
                                colBackground: barRightSideMouseArea.hovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                colRipple: Appearance.colors.colLayer1Active
                                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                                toggled: GlobalStates.sidebarRightOpen
                                property color colText: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0

                                Behavior on colText {
                                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                }

                                onPressed: {
                                    Hyprland.dispatch("hl.dsp.global([[quickshell:sidebarRightToggle]])")
                                }

                                MaterialSymbol {
                                    id: rightSidebarIcon
                                    anchors.centerIn: parent
                                    text: "space_dashboard"
                                    iconSize: bar.sidebarButtonIconSize
                                    color: rightSidebarButton.colText
                                }
                            }

                            SysTray {
                                bar: barRoot
                                visible: barRoot.useShortenedForm === 0
                                Layout.fillWidth: false
                                Layout.fillHeight: true
                            }

                            MinimizedWindows {
                                bar: barRoot
                                Layout.fillWidth: false
                                Layout.fillHeight: true
                            }


                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                            }
                        }
                    }
                }
            }

            // Round decorators
            Item {
                anchors {
                    left: parent.left
                    right: parent.right
                    // top: barContent.bottom
                    top: ConfigOptions.bar.bottom ? undefined : barContent.bottom
                    bottom: ConfigOptions.bar.bottom ? barContent.top : undefined
                }
                height: Appearance.rounding.screenRounding
                visible: showBarBackground && !GlobalStates.gameMode

                RoundCorner {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    size: Appearance.rounding.screenRounding
                    corner: ConfigOptions.bar.bottom ? cornerEnum.bottomLeft : cornerEnum.topLeft
                    color: showBarBackground ? Appearance.colors.colLayer0 : "transparent"
                    opacity: 1.0 - Appearance.transparency
                }
                RoundCorner {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    size: Appearance.rounding.screenRounding
                    corner: ConfigOptions.bar.bottom ? cornerEnum.bottomRight : cornerEnum.topRight
                    color: showBarBackground ? Appearance.colors.colLayer0 : "transparent"
                    opacity: 1.0 - Appearance.transparency
                }
            }

        }

    }

}
