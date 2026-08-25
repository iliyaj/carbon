import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import "root:/Services"
import "root:/Modules/Common/Functions/string_utils.js" as StringUtils
import "root:/Modules/Common/Functions/color_utils.js" as ColorUtils
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets

Item { // Player instance
    id: playerController
    required property MprisPlayer player
    property real trackLength: 0
    property real trackPosition: 0
    property bool playing: false
    property string trackTitle: ""
    property string trackArtist: ""
    property string artUrl: ""
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl) + ".jpg"
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property string displayedArtFilePath: downloaded ? Qt.resolvedUrl(artFilePath) : ""
    property color artDominantColor: colorQuantizer?.colors[0] || Appearance.m3colors.m3secondaryContainer
    property bool downloaded: false
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 1000 // Max value in the data points
    property int visualizerSmoothing: 2 // Number of points to average for smoothing
    readonly property bool hasLiveTrack: player !== null && MprisController.hasTrackData(player)

    // Ignore teardown-only browser artwork and freeze the final real track frame.
    Binding on trackLength {
        when: playerController.hasLiveTrack
        value: MprisController.trackLengthFor(playerController.player)
        restoreMode: Binding.RestoreNone
    }
    Binding on trackPosition {
        when: playerController.hasLiveTrack
        value: playerController.player?.position ?? 0
        restoreMode: Binding.RestoreNone
    }
    Binding on playing {
        when: playerController.hasLiveTrack
        value: playerController.player?.isPlaying ?? false
        restoreMode: Binding.RestoreNone
    }
    Binding on trackTitle {
        when: playerController.hasLiveTrack
        value: playerController.player?.trackTitle ?? ""
        restoreMode: Binding.RestoreNone
    }
    Binding on trackArtist {
        when: playerController.hasLiveTrack
        value: playerController.player?.trackArtist ?? ""
        restoreMode: Binding.RestoreNone
    }
    Binding on artUrl {
        when: playerController.hasLiveTrack
        value: playerController.player?.trackArtUrl ?? ""
        restoreMode: Binding.RestoreNone
    }

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    component TrackChangeButton: RippleButton {
        implicitWidth: 24
        implicitHeight: 24

        property var iconName
        colBackground: ColorUtils.transparentize(blendedColors.colSecondaryContainer, 1)
        colBackgroundHover: blendedColors.colSecondaryContainerHover
        colRipple: blendedColors.colSecondaryContainerActive

        contentItem: MaterialSymbol {
            iconSize: Appearance.font.pixelSize.huge
            fill: 1
            horizontalAlignment: Text.AlignHCenter
            color: blendedColors.colOnSecondaryContainer
            text: iconName

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

    Timer { // Force update for prevision
        running: playerController.hasLiveTrack && playerController.playing
        interval: 1000
        repeat: true
        onTriggered: {
            playerController.player?.positionChanged()
        }
    }

    function downloadCurrentArt(): void {
        downloaded = false

        if (artUrl.length === 0) {
            playerController.artDominantColor = Appearance.m3colors.m3secondaryContainer
            return
        }

        if (coverArtDownloader.running) return

        // Snapshot both bindings together so a metadata change cannot pair a new
        // URL with the previous track's derived cache filename.
        coverArtDownloader.targetFile = artUrl
        coverArtDownloader.outputFile = artFilePath
        coverArtDownloader.running = true
    }

    onArtFilePathChanged: downloadCurrentArt()

    Process { // Cover art downloader
        id: coverArtDownloader
        property string targetFile: ""
        property string outputFile: ""
        command: [
            "bash", "-c",
            `[ -f "$1" ] || curl -4 --fail --silent --show-error --location "$2" --output "$1"`,
            "cover-art", outputFile, targetFile
        ]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && outputFile === playerController.artFilePath) {
                playerController.downloaded = true
            } else if (exitCode !== 0 && outputFile === playerController.artFilePath) {
                console.warn(`[MediaControls] Failed to download cover art: ${targetFile}`)
            }

            // If the track changed while curl was running, fetch only the newest
            // pending artwork after this Process has fully returned to idle.
            if (outputFile !== playerController.artFilePath && playerController.artUrl.length > 0) {
                Qt.callLater(playerController.downloadCurrentArt)
            }
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: playerController.displayedArtFilePath
        depth: 0 // 2^0 = 1 color
        rescaleSize: 1 // Rescale to 1x1 pixel for faster processing
    }

    property bool backgroundIsDark: artDominantColor.hslLightness < 0.5
    property QtObject blendedColors: QtObject {
        property color colLayer0: ColorUtils.mix(Appearance.colors.colLayer0, artDominantColor, (backgroundIsDark && Appearance.m3colors.darkmode) ? 0.6 : 0.5)
        property color colLayer1: ColorUtils.mix(Appearance.colors.colLayer1, artDominantColor, 0.5)
        property color colOnLayer0: ColorUtils.mix(Appearance.colors.colOnLayer0, artDominantColor, 0.5)
        property color colOnLayer1: ColorUtils.mix(Appearance.colors.colOnLayer1, artDominantColor, 0.5)
        property color colSubtext: ColorUtils.mix(Appearance.colors.colOnLayer1, artDominantColor, 0.5)
        property color colPrimary: ColorUtils.mix(ColorUtils.adaptToAccent(Appearance.colors.colPrimary, artDominantColor), artDominantColor, 0.5)
        property color colPrimaryHover: ColorUtils.mix(ColorUtils.adaptToAccent(Appearance.colors.colPrimaryHover, artDominantColor), artDominantColor, 0.3)
        property color colPrimaryActive: ColorUtils.mix(ColorUtils.adaptToAccent(Appearance.colors.colPrimaryActive, artDominantColor), artDominantColor, 0.3)
        property color colSecondaryContainer: ColorUtils.mix(Appearance.m3colors.m3secondaryContainer, artDominantColor, 0.15)
        property color colSecondaryContainerHover: ColorUtils.mix(Appearance.colors.colSecondaryContainerHover, artDominantColor, 0.3)
        property color colSecondaryContainerActive: ColorUtils.mix(Appearance.colors.colSecondaryContainerActive, artDominantColor, 0.5)
        property color colOnPrimary: ColorUtils.mix(ColorUtils.adaptToAccent(Appearance.m3colors.m3onPrimary, artDominantColor), artDominantColor, 0.5)
        property color colOnSecondaryContainer: ColorUtils.mix(Appearance.m3colors.m3onSecondaryContainer, artDominantColor, 0.5)

    }

    StyledRectangularShadow {
        target: background
    }
    Rectangle { // Background
        id: background
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        color: blendedColors.colLayer0
        radius: root.popupRounding

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        Image {
            id: blurredArt
            anchors.fill: parent
            source: playerController.displayedArtFilePath
            sourceSize.width: background.width
            sourceSize.height: background.height
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            asynchronous: true

            layer.enabled: true
            layer.effect: MultiEffect {
                source: blurredArt
                saturation: 0.2
                blurEnabled: true
                blurMax: 100
                blur: 1
            }

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(blendedColors.colLayer0, 0.25)
                radius: root.popupRounding
            }
        }

        WaveVisualizer {
            id: visualizerCanvas
            anchors.fill: parent
            live: playerController.playing
            points: playerController.visualizerPoints
            maxVisualizerValue: playerController.maxVisualizerValue
            smoothing: playerController.visualizerSmoothing
            color: blendedColors.colPrimary
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.contentPadding
            spacing: 15

            Rectangle { // Art background
                id: artBackground
                Layout.fillHeight: true
                implicitWidth: height
                radius: root.artRounding
                color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: artBackground.width
                        height: artBackground.height
                        radius: artBackground.radius
                    }
                }

                Image { // Art image
                    id: mediaArt
                    property int size: parent.height
                    anchors.fill: parent

                    source: playerController.displayedArtFilePath
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true
                    asynchronous: true

                    width: size
                    height: size
                    sourceSize.width: size
                    sourceSize.height: size
                }
            }

            ColumnLayout { // Info & controls
                Layout.fillHeight: true
                spacing: 2

                StyledText {
                    id: trackTitle
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: blendedColors.colOnLayer0
                    elide: Text.ElideRight
                    text: StringUtils.cleanMusicTitle(playerController.trackTitle) || "Untitled"
                }
                StyledText {
                    id: trackArtist
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: blendedColors.colSubtext
                    elide: Text.ElideRight
                    text: playerController.trackArtist
                }
                Item { Layout.fillHeight: true }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: trackTime.implicitHeight + sliderRow.implicitHeight

                    StyledText {
                        id: trackTime
                        anchors.bottom: sliderRow.top
                        anchors.bottomMargin: 5
                        anchors.left: parent.left
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: blendedColors.colSubtext
                        elide: Text.ElideRight
                        text: `${StringUtils.friendlyTimeForSeconds(playerController.trackPosition)} / ${StringUtils.friendlyTimeForSeconds(playerController.trackLength)}`
                    }
                    RowLayout {
                        id: sliderRow
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                        }
                        TrackChangeButton {
                            iconName: "skip_previous"
                            onClicked: playerController.player?.previous()
                        }
                        Item {
                            id: progressBarContainer
                            Layout.fillWidth: true
                            implicitHeight: progressBar.implicitHeight

                            StyledProgressBar {
                                id: progressBar
                                anchors.fill: parent
                                highlightColor: blendedColors.colPrimary
                                trackColor: blendedColors.colSecondaryContainer
                                value: playerController.trackLength > 0
                                    ? playerController.trackPosition / playerController.trackLength
                                    : 0
                                wavy: playerController.playing
                            }
                        }
                        TrackChangeButton {
                            iconName: "skip_next"
                            onClicked: playerController.player?.next()
                        }
                    }

                    RippleButton {
                        id: playPauseButton
                        anchors.right: parent.right
                        anchors.bottom: sliderRow.top
                        anchors.bottomMargin: 5
                        property real size: 44
                        implicitWidth: size
                        implicitHeight: size
                        onClicked: playerController.player?.togglePlaying()

                        buttonRadius: playerController.playing ? Appearance?.rounding.normal : size / 2
                        colBackground: playerController.playing ? blendedColors.colPrimary : blendedColors.colSecondaryContainer
                        colBackgroundHover: playerController.playing ? blendedColors.colPrimaryHover : blendedColors.colSecondaryContainerHover
                        colRipple: playerController.playing ? blendedColors.colPrimaryActive : blendedColors.colSecondaryContainerActive

                        contentItem: MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.huge
                            fill: 1
                            horizontalAlignment: Text.AlignHCenter
                            color: playerController.playing ? blendedColors.colOnPrimary : blendedColors.colOnSecondaryContainer
                            text: playerController.playing ? "pause" : "play_arrow"

                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }
                    }
                }
            }
        }
    }
}
