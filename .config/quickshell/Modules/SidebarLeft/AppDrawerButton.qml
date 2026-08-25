import "root:/Services/"
import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell

/**
 * A single app tile (icon + name) used by the app drawer,
 * both in the categorized view and in search results.
 */
Item {
    id: appItem
    required property var entry
    property real itemSize: 70

    // Emitted on right click; coordinates are relative to this item
    signal menuRequested(real x, real y)

    function launch() {
        AppLauncher.launchDesktopEntry(appItem.entry)
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Appearance.rounding.small
        color: {
            if (mouseArea.pressed) return Appearance.colors.colLayer2Active
            if (mouseArea.containsMouse) return Appearance.colors.colLayer1Hover
            return "transparent"
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -7
            spacing: 0

            // App icon
            Rectangle {
                width: appItem.itemSize
                height: appItem.itemSize
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Appearance.rounding.normal
                color: "transparent"

                Image {
                    id: appIcon
                    anchors.centerIn: parent
                    width: appItem.itemSize * 0.7
                    height: appItem.itemSize * 0.7
                    source: {
                        const iconName = appItem.entry.icon || AppSearch.guessIcon(appItem.entry.name)
                        return Quickshell.iconPath(iconName, false)
                    }
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    cache: true

                    // Fallback icon
                    Rectangle {
                        anchors.fill: parent
                        visible: appIcon.status === Image.Error
                        color: Appearance.colors.colLayer2
                        radius: Appearance.rounding.small

                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: appItem.itemSize * 0.4
                            color: Appearance.colors.colOnLayer2
                            text: "apps"
                        }
                    }
                }

                // Icon shadow effect
                layer.enabled: true
                layer.effect: DropShadow {
                    verticalOffset: 2
                    radius: 4
                    samples: 9
                    color: Qt.rgba(0, 0, 0, 0.15)
                }
            }

            // App name
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                width: appItem.itemSize
                text: {
                    // Check if the name contains non-Latin characters
                    const name = appItem.entry.name
                    const hasNonLatin = /[^\u0000-\u007F]/.test(name)

                    // If it has non-Latin characters and we have an ID, use the ID instead
                    if (hasNonLatin && appItem.entry.id) {
                        // Clean up the ID to make it more readable
                        const cleanId = appItem.entry.id
                            .replace(/\.desktop$/, '')
                            .split('.')
                            .pop()
                            .split('-')
                            .map(word => word.charAt(0).toUpperCase() + word.slice(1))
                            .join(' ')
                        return cleanId
                    }
                    return name
                }
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.family: Appearance.font.family.main
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
                lineHeight: 0.9
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                appItem.menuRequested(mouse.x, mouse.y)
            } else {
                appItem.launch()
            }
        }
    }
}
