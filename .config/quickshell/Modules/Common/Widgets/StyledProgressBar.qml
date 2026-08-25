import "root:/Modules/Common"
import QtQuick
import QtQuick.Controls

/**
 * Material 3 progress bar. See https://m3.material.io/components/progress-indicators/overview
 */
ProgressBar {
    id: root
    property real valueBarWidth: 120
    property real valueBarHeight: 4
    property real valueBarGap: 4
    property color highlightColor: Appearance?.colors.colPrimary ?? "#685496"
    property color trackColor: Appearance?.m3colors.m3secondaryContainer ?? "#F1D3F9"
    property bool wavy: false
    property bool animateWave: true
    property real waveAmplitudeMultiplier: wavy ? 0.5 : 0
    property real waveFrequency: 6
    property real waveFps: 60

    Behavior on waveAmplitudeMultiplier {
        animation: Appearance?.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Behavior on value {
        animation: Appearance?.animation.elementMoveEnter.numberAnimation.createObject(this)
    }

    Behavior on highlightColor {
        animation: Appearance?.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    background: Item {
        anchors.fill: parent
        implicitHeight: valueBarHeight
        implicitWidth: valueBarWidth
    }

    contentItem: Item {
        anchors.fill: parent

        Canvas {
            id: wavyFill
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            height: parent.height * 6

            onPaint: {
                const context = getContext("2d")
                context.clearRect(0, 0, width, height)

                const fillWidth = Math.max(0, Math.min(width, root.visualPosition * width))
                const strokeWidth = parent.height
                const centerY = height / 2
                if (fillWidth <= 0 || strokeWidth <= 0)
                    return

                context.fillStyle = root.highlightColor
                if (fillWidth <= strokeWidth) {
                    context.beginPath()
                    context.arc(fillWidth / 2, centerY, fillWidth / 2, 0, Math.PI * 2)
                    context.fill()
                    return
                }

                const amplitude = strokeWidth * root.waveAmplitudeMultiplier
                const phase = Date.now() / 400
                const startX = strokeWidth / 2
                const endX = fillWidth - strokeWidth / 2
                const waveY = x => centerY + amplitude * Math.sin(root.waveFrequency * 2 * Math.PI * x / width + phase)

                context.strokeStyle = root.highlightColor
                context.lineWidth = strokeWidth
                context.lineCap = "round"
                context.beginPath()
                context.moveTo(startX, waveY(startX))
                for (let x = startX + 1; x < endX; x += 1)
                    context.lineTo(x, waveY(x))
                context.lineTo(endX, waveY(endX))
                context.stroke()
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: root

                function onValueChanged(): void {
                    wavyFill.requestPaint()
                }

                function onHighlightColorChanged(): void {
                    wavyFill.requestPaint()
                }

                function onWaveAmplitudeMultiplierChanged(): void {
                    wavyFill.requestPaint()
                }
            }

            Timer {
                interval: 1000 / root.waveFps
                running: root.wavy && root.animateWave
                repeat: true
                onTriggered: wavyFill.requestPaint()
            }
        }

        Rectangle { // Right remaining part fill
            anchors.right: parent.right
            width: Math.max(0, (1 - root.visualPosition) * parent.width - valueBarGap)
            height: parent.height
            radius: Appearance?.rounding.full ?? 9999
            color: root.trackColor
        }
        Rectangle { // Stop point
            anchors.right: parent.right
            width: valueBarGap
            height: valueBarGap
            radius: Appearance?.rounding.full ?? 9999
            color: root.highlightColor
        }
    }
}
