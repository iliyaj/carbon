import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import "root:/Services"
import "root:/Modules/Common/Functions"
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property bool showAddDialog: false
    property int dialogMargins: 20
    property int fabSize: 48
    property int fabMargins: 14

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_N) {
            root.showAddDialog = true
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape && root.showAddDialog) {
            root.showAddDialog = false
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TaskList {
            Layout.topMargin: 10
            Layout.fillWidth: true
            Layout.fillHeight: true
            listBottomPadding: root.fabSize + root.fabMargins * 2
            emptyPlaceholderIcon: "note"
            emptyPlaceholderText: qsTr("No notes yet")
            taskList: Todo.list
                .map(function(item, i) { return Object.assign({}, item, {originalIndex: i}); })
                .reverse()
        }
    }

    // Open notes folder button
    StyledRectangularShadow {
        target: folderButton
        radius: folderButton.buttonRadius
        blur: 0.6 * Appearance.sizes.elevationMargin
    }
    FloatingActionButton {
        id: folderButton
        baseSize: 40
        anchors.right: parent.right
        anchors.bottom: fabButton.top
        anchors.rightMargin: root.fabMargins + (fabButton.baseSize - baseSize) / 2
        anchors.bottomMargin: root.fabMargins

        onClicked: {
            const folder = Directories.todoPath.substring(0, Directories.todoPath.lastIndexOf('/'))
            Quickshell.execDetached(["xdg-open", folder])
        }

        contentItem: MaterialSymbol {
            text: "folder_open"
            horizontalAlignment: Text.AlignHCenter
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.m3colors.m3onPrimaryContainer
        }

        StyledToolTip {
            content: qsTr("Open notes folder")
        }
    }

    // + FAB
    StyledRectangularShadow {
        target: fabButton
        radius: fabButton.buttonRadius
        blur: 0.6 * Appearance.sizes.elevationMargin
    }
    FloatingActionButton {
        id: fabButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.fabMargins
        anchors.bottomMargin: root.fabMargins

        onClicked: root.showAddDialog = true

        contentItem: MaterialSymbol {
            text: "add"
            horizontalAlignment: Text.AlignHCenter
            iconSize: Appearance.font.pixelSize.huge
            color: Appearance.m3colors.m3onPrimaryContainer
        }
    }

    Item {
        anchors.fill: parent
        z: 9999

        visible: opacity > 0
        opacity: root.showAddDialog ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        onVisibleChanged: {
            if (!visible) {
                todoInput.text = ""
                fabButton.focus = true
            }
        }

        Rectangle { // Scrim
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colors.colScrim
            MouseArea {
                hoverEnabled: true
                anchors.fill: parent
                preventStealing: true
                propagateComposedEvents: false
            }
        }

        Rectangle { // The dialog
            id: dialog
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: root.dialogMargins
            implicitHeight: dialogColumnLayout.implicitHeight

            color: Appearance.colors.colSurfaceContainerHigh
            radius: Appearance.rounding.normal

            function addTask() {
                if (todoInput.text.length > 0) {
                    Todo.addTask(todoInput.text)
                    todoInput.text = ""
                    root.showAddDialog = false

                }
            }

            ColumnLayout {
                id: dialogColumnLayout
                anchors.fill: parent
                spacing: 16

                StyledText {
                    Layout.topMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.alignment: Qt.AlignLeft
                    color: Appearance.m3colors.m3onSurface
                    font.pixelSize: Appearance.font.pixelSize.larger
                    text: qsTr("Add note")
                }

                TextField {
                    id: todoInput
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    padding: 10
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    renderType: Text.NativeRendering
                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                    selectionColor: Appearance.colors.colSecondaryContainer
                    placeholderText: qsTr("Note content")
                    placeholderTextColor: Appearance.m3colors.m3outline
                    focus: root.showAddDialog
                    onAccepted: dialog.addTask()

                    background: Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.verysmall
                        border.width: 2
                        border.color: todoInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                        color: "transparent"
                    }

                    cursorDelegate: Rectangle {
                        width: 1
                        color: todoInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                        radius: 1
                    }
                }

                RowLayout {
                    Layout.bottomMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.alignment: Qt.AlignRight
                    spacing: 5

                    DialogButton {
                        buttonText: qsTr("Cancel")
                        onClicked: root.showAddDialog = false
                    }
                    DialogButton {
                        buttonText: qsTr("Add")
                        enabled: todoInput.text.length > 0
                        onClicked: dialog.addTask()
                    }
                }
            }
        }
    }
}
