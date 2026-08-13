import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import "root:/Services"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    required property var taskList;
    property string emptyPlaceholderIcon
    property string emptyPlaceholderText
    property int todoListItemSpacing: 5
    property int todoListItemPadding: 8
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
                model: ScriptModel {
                    values: taskList
                }
                delegate: Item {
                    id: todoItem
                    property bool pendingDelete: false
                    property bool enableHeightAnimation: false

                    Layout.fillWidth: true
                    implicitHeight: todoItemRectangle.implicitHeight + todoListItemSpacing
                    height: implicitHeight
                    clip: true

                    Behavior on implicitHeight {
                        enabled: enableHeightAnimation
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    function startDelete() {
                        enableHeightAnimation = true
                        todoItem.implicitHeight = 0
                        deleteTimer.start()
                    }

                    Timer {
                        id: deleteTimer
                        interval: Appearance.animation.elementMoveFast.duration
                        repeat: false
                        onTriggered: Todo.deleteItem(modelData.originalIndex)
                    }

                    Process {
                        id: copyProcess
                        function startCopy(text) {
                            copyProcess.command = ["wl-copy", text]
                            copyProcess.running = true
                        }
                    }

                    Rectangle {
                        id: todoItemRectangle
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        implicitHeight: todoContentRowLayout.implicitHeight
                        color: Appearance.colors.colLayer2
                        radius: Appearance.rounding.small
                        ColumnLayout {
                            id: todoContentRowLayout
                            anchors.left: parent.left
                            anchors.right: parent.right

                            StyledText {
                                Layout.fillWidth: true // Needed for wrapping
                                Layout.leftMargin: 10
                                Layout.rightMargin: 10
                                Layout.topMargin: todoListItemPadding
                                id: todoContentText
                                text: modelData.content
                                wrapMode: Text.Wrap
                            }
                            RowLayout {
                                Layout.leftMargin: 10
                                Layout.rightMargin: 10
                                Layout.bottomMargin: todoListItemPadding
                                Item {
                                    Layout.fillWidth: true
                                }
                                StyledText {
                                    font.pixelSize: Appearance.font.pixelSize.small - 2
                                    color: Appearance.m3colors.m3outline
                                    opacity: 0.5
                                    text: modelData.createdAt ? Qt.formatDateTime(new Date(modelData.createdAt), "d MMM yyyy, hh:mm") : ""
                                    visible: modelData.createdAt !== undefined
                                }
                                RowLayout {
                                    spacing: 0
                                    TodoItemActionButton {
                                        Layout.fillWidth: false
                                        onClicked: copyProcess.startCopy(modelData.content)
                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            text: "content_copy"
                                            iconSize: Appearance.font.pixelSize.larger
                                            color: Appearance.colors.colOnLayer1
                                        }
                                        StyledToolTip {
                                            content: "Copy"
                                        }
                                    }
                                    TodoItemActionButton {
                                        Layout.fillWidth: false
                                        onClicked: todoItem.startDelete()
                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            text: "delete_forever"
                                            iconSize: Appearance.font.pixelSize.larger
                                            color: Appearance.colors.colOnLayer1
                                        }
                                        StyledToolTip {
                                            content: "Delete"
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
                implicitHeight: listBottomPadding
            }
        }
    }

    Item { // Placeholder when list is empty
        visible: opacity > 0
        opacity: taskList.length === 0 ? 1 : 0
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
                text: emptyPlaceholderIcon
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3outline
                horizontalAlignment: Text.AlignHCenter
                text: emptyPlaceholderText
            }
        }
    }
}
