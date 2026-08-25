import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import "root:/Modules/Common/Functions"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root
    property int currentIndex: 0
    property bool expanded: false
    property real itemSpacing: Appearance.spacing.xs
    default property alias data: tabBarColumn.data
    implicitHeight: tabBarColumn.implicitHeight
    implicitWidth: tabBarColumn.implicitWidth
    Layout.topMargin: 25
    Rectangle {
        property real itemHeight: tabBarColumn.children[0].baseSize
        property real baseHighlightHeight: tabBarColumn.children[0].baseHighlightHeight
        anchors {
            top: tabBarColumn.top
            left: tabBarColumn.left
            topMargin: (itemHeight + root.itemSpacing) * root.currentIndex
                + (root.expanded ? 0 : ((itemHeight - baseHighlightHeight) / 2))
        }
        radius: root.expanded ? Appearance.rounding.small : Appearance.rounding.normal
        color: Appearance.colors.colSecondaryContainer
        implicitHeight: root.expanded ? itemHeight : baseHighlightHeight
        implicitWidth: tabBarColumn.children[root.currentIndex].visualWidth

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
    }
    ColumnLayout {
        id: tabBarColumn
        anchors.fill: parent
        spacing: root.itemSpacing

    }
}
