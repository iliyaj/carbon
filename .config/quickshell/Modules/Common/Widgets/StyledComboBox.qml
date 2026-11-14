pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Modules.Common
import qs.Modules.Common.Widgets

ComboBox {
    id: root
    implicitHeight: 44
    opacity: enabled ? 1 : 0.4

    background: Rectangle {
        radius: Appearance.rounding.small
        color: root.down
            ? Appearance.colors.colSecondaryContainerActive
            : root.hovered
            ? Appearance.colors.colSecondaryContainerHover
            : Appearance.colors.colSecondaryContainer
        border.width: root.activeFocus ? 2 : 0
        border.color: Appearance.m3colors.m3primary

        PointingHandInteraction {}
    }
    contentItem: StyledText {
        leftPadding: Appearance.spacing.md
        rightPadding: 40
        text: root.displayText
        color: Appearance.colors.colOnSecondaryContainer
        elide: Text.ElideRight
    }
    indicator: MaterialSymbol {
        x: root.width - width - Appearance.spacing.md
        anchors.verticalCenter: parent.verticalCenter
        text: "expand_more"
        iconSize: 22
        color: Appearance.colors.colOnSecondaryContainer
        rotation: root.popup.visible ? 180 : 0
        Behavior on rotation {
            NumberAnimation { duration: 120 }
        }
    }
    delegate: ItemDelegate {
        id: optionDelegate
        required property var modelData
        required property int index
        readonly property bool selected: root.currentIndex === index
        width: ListView.view?.width ?? root.width
        implicitHeight: 42
        highlighted: root.highlightedIndex === index
        contentItem: StyledText {
            leftPadding: Appearance.spacing.md
            rightPadding: 36
            text: root.textAt(optionDelegate.index)
            color: optionDelegate.selected
                ? Appearance.colors.colOnSecondaryContainer
                : Appearance.colors.colOnLayer2
            elide: Text.ElideRight
        }
        indicator: MaterialSymbol {
            anchors.right: parent.right
            anchors.rightMargin: Appearance.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            text: "check"
            iconSize: 20
            color: Appearance.colors.colOnSecondaryContainer
            visible: optionDelegate.selected
        }
        background: Rectangle {
            radius: Appearance.rounding.small
            color: optionDelegate.selected
                ? optionDelegate.down ? Appearance.colors.colSecondaryContainerActive
                    : optionDelegate.highlighted || optionDelegate.hovered ? Appearance.colors.colSecondaryContainerHover
                    : Appearance.colors.colSecondaryContainer
                : optionDelegate.down ? Appearance.colors.colLayer2Active
                    : optionDelegate.highlighted || optionDelegate.hovered ? Appearance.colors.colLayer2Hover
                    : "transparent"

            PointingHandInteraction {}
        }
    }
    popup: Popup {
        y: root.height + 4
        width: root.width
        height: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, 320)
        padding: Appearance.spacing.xs
        background: Rectangle {
            radius: Appearance.rounding.normal
            color: Appearance.m3colors.m3surfaceContainerHigh
            border.width: 1
            border.color: Appearance.m3colors.m3outlineVariant
        }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
        }
    }
}
