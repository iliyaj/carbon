//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "root:/Services/"
import "root:/Modules/Common/"
import "root:/Modules/Common/Widgets/"

ApplicationWindow {
    id: root

    readonly property color canvasColor: "#0b0d10"
    readonly property color panelColor: "#12151a"
    readonly property color raisedColor: "#1a1e24"
    readonly property color outlineColor: "#2b3038"
    readonly property color primaryText: "#f3f5f7"
    readonly property color secondaryText: "#939aa5"
    readonly property color accentColor: Appearance.m3colors.m3primary
    readonly property color successColor: "#8bd5a5"

    readonly property var controlMappings: [
        {
            icon: "terminal",
            control: qsTr("Wheel click"),
            purpose: qsTr("Open terminal"),
            action: root.formatAction(MXMaster3.buttonBindings.find(binding => binding.label === qsTr("Wheel click"))?.action ?? "")
        },
        {
            icon: "volume_down",
            control: qsTr("Thumb wheel · left"),
            purpose: qsTr("Volume down"),
            action: root.formatAction(MXMaster3.thumbwheelLeftAction)
        },
        {
            icon: "volume_up",
            control: qsTr("Thumb wheel · right"),
            purpose: qsTr("Volume up"),
            action: root.formatAction(MXMaster3.thumbwheelRightAction)
        },
        {
            icon: "arrow_forward",
            control: qsTr("Forward"),
            purpose: qsTr("Next workspace"),
            action: root.formatAction(MXMaster3.forwardButtonAction)
        },
        {
            icon: "arrow_back",
            control: qsTr("Back"),
            purpose: qsTr("Previous workspace"),
            action: root.formatAction(MXMaster3.backButtonAction)
        },
        {
            icon: "gesture",
            control: qsTr("Gesture button"),
            purpose: qsTr("Open launcher"),
            action: root.formatAction(MXMaster3.gestureButtonAction)
        }
    ]

    function formatAction(action: string): string {
        if (!action)
            return "—"

        const names = {
            LEFTCTRL: qsTr("Ctrl"),
            RIGHTCTRL: qsTr("Ctrl"),
            LEFTMETA: qsTr("Super"),
            RIGHTMETA: qsTr("Super"),
            LEFTSHIFT: qsTr("Shift"),
            RIGHTSHIFT: qsTr("Shift"),
            LEFTALT: qsTr("Alt"),
            RIGHTALT: qsTr("Alt"),
            LEFT: "←",
            RIGHT: "→",
            UP: "↑",
            DOWN: "↓",
            VOLUMEDOWN: qsTr("Volume −"),
            VOLUMEUP: qsTr("Volume +")
        }
        return action.split(" + ").map(key => names[key] ?? key).join(" + ")
    }

    component StatTile: Rectangle {
        id: statTile

        required property string icon
        required property string label
        required property string value

        implicitHeight: 72
        radius: Appearance.rounding.normal
        color: root.raisedColor
        border.width: 1
        border.color: root.outlineColor

        RowLayout {
            anchors {
                fill: parent
                margins: Appearance.spacing.md
            }
            spacing: Appearance.spacing.sm

            MaterialSymbol {
                text: statTile.icon
                iconSize: 20
                color: root.accentColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    text: statTile.value
                    color: root.primaryText
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                }
                StyledText {
                    text: statTile.label
                    color: root.secondaryText
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }

    component ControlRow: Rectangle {
        id: controlRow

        required property string icon
        required property string control
        required property string purpose
        required property string action

        implicitHeight: 64
        radius: Appearance.rounding.normal
        color: root.raisedColor
        border.width: 1
        border.color: root.outlineColor

        RowLayout {
            anchors {
                fill: parent
                leftMargin: Appearance.spacing.sm
                rightMargin: Appearance.spacing.sm
            }
            spacing: Appearance.spacing.sm

            Rectangle {
                implicitWidth: 36
                implicitHeight: 36
                radius: Appearance.rounding.small
                color: "#232832"

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: controlRow.icon
                    iconSize: 19
                    color: root.accentColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: controlRow.control
                    color: root.primaryText
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: controlRow.purpose
                    color: root.secondaryText
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                implicitWidth: shortcutText.implicitWidth + Appearance.spacing.sm * 2
                implicitHeight: 30
                radius: Appearance.rounding.small
                color: "#0d1015"
                border.width: 1
                border.color: "#353b45"

                StyledText {
                    id: shortcutText
                    anchors.centerIn: parent
                    text: controlRow.action
                    color: "#c8cdd4"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                }
            }
        }
    }

    title: MXMaster3.modelName
    visible: true
    onClosing: Qt.quit()
    width: 1060
    height: 680
    minimumWidth: 800
    minimumHeight: 560
    color: root.canvasColor

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        MXMaster3.refresh()
    }

    Rectangle {
        anchors.fill: parent
        color: root.canvasColor

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#0f1217" }
            GradientStop { position: 0.55; color: root.canvasColor }
            GradientStop { position: 1; color: "#090b0e" }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: Appearance.spacing.lg
        }
        spacing: Appearance.spacing.lg

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: MXMaster3.modelName
                    color: root.primaryText
                    font.family: Appearance.font.family.title
                    font.pixelSize: Appearance.font.pixelSize.title
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                implicitWidth: connectionRow.implicitWidth + Appearance.spacing.md * 2
                implicitHeight: 34
                radius: 17
                color: MXMaster3.batteryLow ? "#2a1d20"
                    : MXMaster3.batteryAvailable ? "#17261d" : "#20242a"
                border.width: 1
                border.color: MXMaster3.batteryLow ? "#5b363d"
                    : MXMaster3.batteryAvailable ? "#2e5039" : root.outlineColor

                RowLayout {
                    id: connectionRow
                    anchors.centerIn: parent
                    spacing: Appearance.spacing.xs

                    MaterialSymbol {
                        text: MXMaster3.batteryMaterialIcon
                        iconSize: 17
                        color: MXMaster3.batteryLow ? Appearance.m3colors.m3error
                            : MXMaster3.batteryAvailable ? root.successColor : root.secondaryText
                    }
                    StyledText {
                        text: MXMaster3.batteryText
                        color: MXMaster3.batteryLow ? Appearance.m3colors.m3error
                            : MXMaster3.batteryAvailable ? root.successColor : root.secondaryText
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                    }
                }
            }

            RippleButton {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                buttonRadius: Appearance.rounding.normal
                colBackground: root.raisedColor
                colBackgroundHover: "#252a31"
                colRipple: "#343b46"
                onClicked: MXMaster3.refresh()

                contentItem: MaterialSymbol {
                    text: "refresh"
                    iconSize: 21
                    color: root.primaryText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                StyledToolTip {
                    content: qsTr("Refresh device status")
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.lg

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 410
                radius: Appearance.rounding.large
                color: "#090b0e"
                border.width: 1
                border.color: root.outlineColor
                clip: true

                Image {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        bottom: stats.top
                        margins: Appearance.spacing.md
                        topMargin: Appearance.spacing.md
                    }
                    source: MXMaster3.imageSource
                    sourceSize.width: 1100
                    fillMode: Image.PreserveAspectFit
                    horizontalAlignment: Image.AlignHCenter
                    verticalAlignment: Image.AlignVCenter
                    opacity: 0.94
                    smooth: true
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: 150
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#090b0e00" }
                        GradientStop { position: 0.35; color: "#090b0ed9" }
                        GradientStop { position: 1; color: "#090b0eff" }
                    }
                }

                RowLayout {
                    id: stats
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: Appearance.spacing.lg
                    }
                    z: 2
                    spacing: Appearance.spacing.sm

                    StatTile {
                        Layout.fillWidth: true
                        icon: "speed"
                        value: MXMaster3.dpi > 0 ? `${MXMaster3.dpi}` : "—"
                        label: qsTr("DPI")
                    }
                    StatTile {
                        Layout.fillWidth: true
                        icon: "tune"
                        value: MXMaster3.smartShiftEnabled ? `${MXMaster3.smartShiftThreshold}` : qsTr("Off")
                        label: qsTr("SmartShift")
                    }
                    StatTile {
                        Layout.fillWidth: true
                        icon: "360"
                        value: MXMaster3.hiResScrollEnabled ? qsTr("Hi-res") : qsTr("Standard")
                        label: MXMaster3.naturalScroll ? qsTr("Natural scroll") : qsTr("Standard direction")
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 390
                Layout.minimumWidth: 370
                Layout.fillHeight: true
                radius: Appearance.rounding.large
                color: root.panelColor
                border.width: 1
                border.color: root.outlineColor

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: Appearance.spacing.lg
                    }
                    spacing: Appearance.spacing.md

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                text: qsTr("CONTROL MAP")
                                color: root.primaryText
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.8
                            }
                            StyledText {
                                text: qsTr("Active button assignments")
                                color: root.secondaryText
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }

                        Rectangle {
                            implicitWidth: bindingCount.implicitWidth + Appearance.spacing.sm * 2
                            implicitHeight: 26
                            radius: 13
                            color: "#252a31"

                            StyledText {
                                id: bindingCount
                                anchors.centerIn: parent
                                text: `${root.controlMappings.length}`
                                color: root.secondaryText
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Flickable {
                        id: controlFlickable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: width
                        contentHeight: controlList.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick

                        ScrollBar.vertical: ScrollBar {
                            policy: controlFlickable.contentHeight > controlFlickable.height
                                ? ScrollBar.AsNeeded
                                : ScrollBar.AlwaysOff
                        }

                        Column {
                            id: controlList
                            width: controlFlickable.width
                            spacing: Appearance.spacing.sm

                            Repeater {
                                model: root.controlMappings

                                ControlRow {
                                    required property var modelData
                                    width: controlList.width
                                    icon: modelData.icon
                                    control: modelData.control
                                    purpose: modelData.purpose
                                    action: modelData.action
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.xs

                        MaterialSymbol {
                            text: "lock"
                            iconSize: 14
                            color: root.secondaryText
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Read-only · /etc/logid.cfg")
                            color: root.secondaryText
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }
        }
    }
}
