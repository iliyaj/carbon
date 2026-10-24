import qs.Modules.Common
import qs.Modules.Common.Widgets
import qs.Services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property int noteSpacing: 5
    property int notePadding: 8
    property int listBottomPadding: 80

    Flickable {
        id: flickable
        anchors.fill: parent
        contentHeight: columnLayout.height

        clip: true
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: flickable.width
                height: flickable.height
                radius: Appearance.rounding.small
            }
        }

        ColumnLayout {
            id: columnLayout
            width: parent.width
            spacing: 0
            Repeater {
                model: Notes.model
                delegate: Item {
                    id: noteItem
                    required property string filePath
                    required property date fileModified
                    readonly property var note: Notes.parse(noteFile.text())
                    property bool enableHeightAnimation: false

                    Layout.fillWidth: true
                    implicitHeight: noteRectangle.implicitHeight + root.noteSpacing
                    height: implicitHeight
                    clip: true

                    Behavior on implicitHeight {
                        enabled: noteItem.enableHeightAnimation
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    function startDelete() {
                        enableHeightAnimation = true
                        noteItem.implicitHeight = 0
                        deleteTimer.start()
                    }

                    FileView {
                        id: noteFile
                        path: noteItem.filePath
                        blockLoading: true // no height jump while the list rebuilds
                        watchChanges: true
                        onFileChanged: reload()
                    }

                    Timer {
                        id: deleteTimer
                        interval: Appearance.animation.elementMoveFast.duration
                        repeat: false
                        onTriggered: {
                            noteFile.watchChanges = false // skip reloading the deleted file
                            Notes.remove(noteItem.filePath)
                        }
                    }

                    Rectangle {
                        id: noteRectangle
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        implicitHeight: noteContentLayout.implicitHeight
                        color: Appearance.colors.colLayer2
                        radius: Appearance.rounding.small
                        ColumnLayout {
                            id: noteContentLayout
                            anchors.left: parent.left
                            anchors.right: parent.right

                            StyledText {
                                Layout.fillWidth: true // Needed for wrapping
                                Layout.leftMargin: 10
                                Layout.rightMargin: 10
                                Layout.topMargin: root.notePadding
                                text: noteItem.note.body
                                wrapMode: Text.Wrap
                            }
                            RowLayout {
                                Layout.leftMargin: 10
                                Layout.rightMargin: 10
                                Layout.bottomMargin: root.notePadding
                                Item {
                                    Layout.fillWidth: true
                                }
                                StyledText {
                                    font.pixelSize: Appearance.font.pixelSize.small - 2
                                    color: Appearance.m3colors.m3outline
                                    opacity: 0.5
                                    text: Qt.formatDateTime(noteItem.note.createdAt ?? noteItem.fileModified, "d MMM yyyy, hh:mm")
                                }
                                RowLayout {
                                    spacing: 0
                                    NoteActionButton {
                                        Layout.fillWidth: false
                                        tooltipText: qsTr("Copy")
                                        onClicked: Quickshell.clipboardText = noteItem.note.body
                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            text: "content_copy"
                                            iconSize: Appearance.font.pixelSize.larger
                                            color: Appearance.colors.colOnLayer1
                                        }
                                    }
                                    NoteActionButton {
                                        Layout.fillWidth: false
                                        tooltipText: qsTr("Delete")
                                        onClicked: noteItem.startDelete()
                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            text: "delete_forever"
                                            iconSize: Appearance.font.pixelSize.larger
                                            color: Appearance.colors.colOnLayer1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

            }
            // Bottom padding
            Item {
                implicitHeight: root.listBottomPadding
            }
        }
    }

    Item { // Placeholder when list is empty
        visible: opacity > 0
        opacity: Notes.model.count === 0 ? 1 : 0
        anchors.fill: parent

        Behavior on opacity {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 55
                color: Appearance.m3colors.m3outline
                text: "note"
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3outline
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("No notes yet")
            }
        }
    }
}
