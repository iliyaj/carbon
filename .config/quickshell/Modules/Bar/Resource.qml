import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import QtQuick

Item {
    id: root

    required property string label
    required property double percentage
    readonly property real boundedPercentage: Math.max(0, Math.min(1, percentage))
    readonly property int percentageValue: Math.round(boundedPercentage * 100)
    readonly property int severity: percentageValue >= 90 ? 3
        : percentageValue > 50 ? 2
        : percentageValue === 50 ? 1 : 0
    readonly property color fillColor: severity === 3 ? Appearance.colors.colResourceCritical
        : severity === 2 ? Appearance.colors.colResourceWarning
        : severity === 1 ? Appearance.colors.colResourceNeutral
        : Appearance.colors.colResourceNormal
    readonly property color filledTextColor: severity === 3 ? Appearance.colors.colOnResourceCritical
        : severity === 2 ? Appearance.colors.colOnResourceWarning
        : severity === 1 ? Appearance.colors.colOnResourceNeutral
        : Appearance.colors.colOnResourceNormal
    readonly property int outlineWidth: 2

    clip: true
    implicitWidth: baseLabel.implicitWidth + Appearance.spacing.sm * 2
    implicitHeight: 24

    Rectangle {
        id: pill

        anchors.fill: parent
        radius: Appearance.rounding.full
        color: Appearance.colors.colSurfaceContainerHigh
        clip: true

        Item {
            id: fillMask

            anchors.left: parent.left
            anchors.leftMargin: root.outlineWidth
            anchors.top: parent.top
            anchors.topMargin: root.outlineWidth
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.outlineWidth
            width: root.percentageValue / 100 * (parent.width - root.outlineWidth * 2)
            clip: true

            Rectangle {
                id: fill

                width: pill.width - root.outlineWidth * 2
                height: fillMask.height
                radius: height / 2
                color: root.fillColor

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }

            Behavior on width {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }
        }

        StyledText {
            id: baseLabel

            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            font.weight: Font.Bold
            color: Appearance.m3colors.m3onSurface
            text: `${root.label} ${root.percentageValue}`
        }

        Item {
            anchors.left: parent.left
            anchors.leftMargin: root.outlineWidth
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: fillMask.width
            clip: true

            StyledText {
                x: -root.outlineWidth
                width: pill.width
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -1
                horizontalAlignment: Text.AlignHCenter
                font.weight: baseLabel.font.weight
                color: root.filledTextColor
                text: baseLabel.text
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: root.outlineWidth
            border.color: Appearance.colors.colOutlineVariant
        }
    }
}
