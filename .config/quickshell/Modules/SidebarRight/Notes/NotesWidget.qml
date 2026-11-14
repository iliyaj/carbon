import qs.Modules.Common
import qs.Modules.Common.Widgets
import qs.Services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property bool showAddDialog: false
    property int dialogMargins: 20
    property int fabSize: 36
    property int fabMargins: 10

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

        NoteList {
            id: noteList
            Layout.topMargin: 10
            Layout.fillWidth: true
            Layout.fillHeight: true
            listBottomPadding: root.fabSize + root.fabMargins * 2
        }
    }

    RowLayout {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.fabMargins
        spacing: 6

        FloatingActionButton {
            baseSize: root.fabSize
            implicitWidth: baseSize
            iconText: "folder_open"
            Accessible.name: qsTr("Open notes folder")
            onClicked: Quickshell.execDetached(["xdg-open", Directories.notesPath])

            StyledToolTip { content: qsTr("Open notes folder") }
        }
        FloatingActionButton {
            id: fabButton
            baseSize: root.fabSize
            implicitWidth: baseSize
            iconText: "add"
            Accessible.name: qsTr("Add note")
            onClicked: root.showAddDialog = true

            StyledToolTip { content: qsTr("Add note") }
        }
        FloatingActionButton {
            baseSize: root.fabSize
            implicitWidth: baseSize
            iconText: Notes.generating ? "hourglass_top" : "auto_awesome"
            enabled: noteList.canGenerate && !Notes.generating
            opacity: enabled ? 1 : 0.4
            Accessible.name: qsTr("Generate title and tags for selected note")
            onClicked: noteList.generateSelected()

            StyledToolTip { content: qsTr("Generate title and tags for selected note") }
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
                noteInput.text = ""
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

            function addNote() {
                if (noteInput.text.length > 0) {
                    Notes.add(noteInput.text)
                    noteInput.text = ""
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
                    id: noteInput
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
                    onAccepted: dialog.addNote()

                    background: Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.verysmall
                        border.width: 2
                        border.color: noteInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                        color: "transparent"
                    }

                    cursorDelegate: Rectangle {
                        width: 1
                        color: noteInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
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
                        enabled: noteInput.text.length > 0
                        onClicked: dialog.addNote()
                    }
                }
            }
        }
    }
}
