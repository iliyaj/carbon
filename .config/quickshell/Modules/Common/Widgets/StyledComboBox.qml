pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Modules.Common
import qs.Modules.Common.Widgets

ComboBox {
    id: root
    implicitHeight: 44

    background: Rectangle {
        radius: Appearance.rounding.small
        color: root.hovered
            ? Appearance.colors.colSecondaryContainerHover
            : Appearance.colors.colSecondaryContainer
        border.width: root.activeFocus ? 2 : 0
        border.color: Appearance.m3colors.m3primary
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
        width: ListView.view?.width ?? root.width
        implicitHeight: 42
        highlighted: root.highlightedIndex === index
        contentItem: StyledText {
            text: root.textAt(optionDelegate.index)
            color: Appearance.colors.colOnLayer2
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: Appearance.rounding.small
            color: optionDelegate.highlighted
                ? Appearance.colors.colLayer2Hover
                : "transparent"
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
