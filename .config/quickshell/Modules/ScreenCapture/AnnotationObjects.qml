pragma ComponentBehavior: Bound

import qs.Modules.Common.Widgets
import "annotation_tools.js" as AnnotationTools
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property var shapes: []
    property int selectedIndex: -1
    signal selectionRequested(int index)
    signal editRequested()
    signal deleteRequested()
    signal reorderRequested(int direction)
    color: "#242424"
    implicitWidth: 208

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Annotations (%1)").arg(root.shapes.length)
            color: "#eeeeee"
        }
        ListView {
            id: objectList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.shapes.length
            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                id: row
                required property int index
                readonly property int objectIndex: root.shapes.length - 1 - index
                readonly property var shape: root.shapes[objectIndex]
                width: objectList.width
                height: 40
                radius: 4
                color: root.selectedIndex === objectIndex ? "#556677" : "#22ffffff"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    Rectangle {
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: 6
                        color: AnnotationTools.usesColor(row.shape?.type) ? row.shape?.color ?? "transparent" : "transparent"
                        border.color: "#999999"
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.objectTitle(row.shape)
                        elide: Text.ElideRight
                        color: "#eeeeee"
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectionRequested(row.objectIndex)
                    onDoubleClicked: {
                        root.selectionRequested(row.objectIndex);
                        root.editRequested();
                    }
                }
            }
        }
        StyledText {
            Layout.fillWidth: true
            visible: root.shapes.length === 0
            text: qsTr("Draw to add an annotation")
            wrapMode: Text.WordWrap
            color: "#bbbbbb"
        }
        RowLayout {
            Layout.fillWidth: true
            Button {
                Layout.fillWidth: true
                text: qsTr("Edit text")
                enabled: root.selectedIndex >= 0 && root.shapes[root.selectedIndex]?.type === "text"
                onClicked: root.editRequested()
            }
            Button {
                text: qsTr("Delete")
                enabled: root.selectedIndex >= 0
                onClicked: root.deleteRequested()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Button {
                Layout.fillWidth: true
                text: qsTr("Raise")
                enabled: root.selectedIndex >= 0 && root.selectedIndex < root.shapes.length - 1
                onClicked: root.reorderRequested(1)
            }
            Button {
                Layout.fillWidth: true
                text: qsTr("Lower")
                enabled: root.selectedIndex > 0
                onClicked: root.reorderRequested(-1)
            }
        }
    }

    function objectTitle(shape): string {
        if (!shape) return "";
        switch (shape.type) {
        case "text": return shape.text.split("\n")[0] || qsTr("Text");
        case "counter": return qsTr("Counter %1").arg(shape.number);
        case "pen": return qsTr("Freehand pen");
        case "line": return qsTr("Line");
        case "arrow": return qsTr("Arrow");
        case "rect": return qsTr("Rectangle");
        case "fill": return qsTr("Filled rectangle");
        case "ellipse": return qsTr("Ellipse");
        case "marker": return qsTr("Highlighter");
        case "conceal": return qsTr("Concealed region");
        case "pixelate": return qsTr("Pixelated region (visual)");
        case "blur": return qsTr("Blurred region (visual)");
        case "solid": return qsTr("Solid redaction");
        case "invert": return qsTr("Inverted region");
        default: return shape.type;
        }
    }
}
