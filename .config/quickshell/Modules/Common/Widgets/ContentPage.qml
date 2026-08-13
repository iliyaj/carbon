import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "root:/Modules/Common/"
import "root:/Modules/Common/Widgets/"

Flickable {
    id: root
    property real baseWidth: 550
    property bool forceWidth: false
    property real horizontalPadding: Appearance.spacing.xl
    property real topPadding: Appearance.spacing.lg
    property real bottomContentPadding: Appearance.spacing.xl
    property real scrollTargetY: 0

    default property alias data: contentColumn.data

    clip: true
    contentHeight: contentColumn.implicitHeight + root.topPadding + root.bottomContentPadding
    implicitWidth: contentColumn.implicitWidth

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function(event) {
            const maximumY = Math.max(0, root.contentHeight - root.height)
            const base = scrollAnimation.running ? root.scrollTargetY : root.contentY
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y
            root.scrollTargetY = Math.max(0, Math.min(base - delta * 0.5, maximumY))
            root.contentY = root.scrollTargetY
            event.accepted = true
        }
    }

    Behavior on contentY {
        NumberAnimation {
            id: scrollAnimation
            duration: Appearance.animation.scroll.duration
            easing.type: Appearance.animation.scroll.type
            easing.bezierCurve: Appearance.animation.scroll.bezierCurve
        }
    }

    onContentYChanged: {
        if (!scrollAnimation.running)
            root.scrollTargetY = root.contentY
    }

    ColumnLayout {
        id: contentColumn
        width: root.forceWidth
            ? Math.min(root.baseWidth, Math.max(0, root.width - root.horizontalPadding * 2))
            : Math.max(root.baseWidth, implicitWidth)
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: root.topPadding
        }
        spacing: Appearance.spacing.lg
    }
}
