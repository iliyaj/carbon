import "root:/Modules/Common"
import "root:/Modules/Common/Functions"
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real level: 0
    property bool active: false
    property real thickness: 2
    property color trackColor: ColorUtils.transparentize(Appearance.colors.colOnLayer2, 0.85)
    property color fillColor: Appearance.colors.colPrimary

    property real displayedLevel: active ? level : 0

    Behavior on displayedLevel {
        NumberAnimation {
            duration: 130
            easing.type: Easing.OutCubic
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: root.active ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (Math.min(root.width, root.height) - root.thickness) / 2
                radiusY: (Math.min(root.width, root.height) - root.thickness) / 2
                startAngle: 90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.fillColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (Math.min(root.width, root.height) - root.thickness) / 2
                radiusY: (Math.min(root.width, root.height) - root.thickness) / 2
                startAngle: 90
                sweepAngle: 360 * root.displayedLevel
            }
        }
    }
}
