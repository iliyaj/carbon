pragma ComponentBehavior: Bound

import qs.Modules.Common
import qs.Modules.Common.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

FloatingWindow {
    id: root
    required property var owner
    title: qsTr("Screenshot capture options")
    visible: true
    implicitWidth: 480
    implicitHeight: content.implicitHeight + 32
    minimumSize: Qt.size(440, 560)
    color: Appearance.m3colors.m3surfaceContainer
    property string errorMessage: ""
    signal dismissed()
    onClosed: dismiss()

    function dismiss(): void {
        content.forceActiveFocus()
        dismissed()
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        anchors.margins: 16
        contentWidth: availableWidth

        ColumnLayout {
            id: content
            width: scroll.availableWidth
            spacing: 10
            Label { text: qsTr("Screenshot capture"); font.pixelSize: 22; color: Appearance.m3colors.m3onSurface }
            RowLayout {
                Label { text: qsTr("Area") }
                ComboBox {
                    id: target
                    Layout.fillWidth: true
                    model: [qsTr("Active monitor"), qsTr("Choose monitor"), qsTr("Entire desktop")]
                }
            }
            ComboBox {
                id: monitor
                Layout.fillWidth: true
                visible: target.currentIndex === 1
                model: Quickshell.screens.map(screen => screen.name)
            }
            RowLayout {
                Label { text: qsTr("Delay (seconds)") }
                SpinBox { id: delay; from: 0; to: 86400; value: ConfigOptions.screenshot.delay; editable: true }
            }
            RowLayout {
                Label { text: qsTr("Selection") }
                ComboBox {
                    id: selection
                    Layout.fillWidth: true
                    model: [qsTr("Choose a region"), qsTr("Select all"), qsTr("Reuse last region")]
                }
            }
            CheckBox { id: initial; text: qsTr("Start with an exact region"); enabled: selection.currentIndex === 0 }
            RowLayout {
                visible: initial.checked && initial.enabled
                Repeater {
                    model: [qsTr("X"), qsTr("Y"), qsTr("Width"), qsTr("Height")]
                    delegate: ColumnLayout {
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        property alias value: field.value
                        Label { text: modelData }
                        SpinBox {
                            id: field
                            objectName: "captureRegionValue" + index
                            Layout.fillWidth: true
                            from: index < 2 ? 0 : 1
                            to: 100000
                            value: index < 2 ? 0 : 1080
                            editable: true
                        }
                    }
                    id: regionFields
                }
            }
            CheckBox { id: edit; text: qsTr("Open in the screenshot editor") }
            CheckBox { id: quick; text: qsTr("Accept a new selection when the mouse is released"); checked: ConfigOptions.screenshot.acceptOnSelection; enabled: selection.currentIndex === 0 }
            CheckBox { id: concurrent; text: qsTr("Allow an independent capture while another is open"); checked: ConfigOptions.screenshot.concurrent }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Appearance.m3colors.m3onSurface
                text: qsTr("Dimensions are screenshot pixels. Select all skips region selection. Last region requires the same monitor layout. Without editing, capture saves and copies the image.")
            }
            Label {
                Layout.fillWidth: true
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                wrapMode: Text.WordWrap
                color: Appearance.m3colors.m3error
            }
            Repeater {
                model: root.owner.sessions
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Capture %1 — %2%3").arg(modelData.sessionId).arg(modelData.state)
                            .arg(modelData.countdown > 0 ? " (" + modelData.countdown + " s)" : "")
                    }
                    DialogButton { buttonText: qsTr("Cancel"); onClicked: root.owner.cancel(modelData.sessionId) }
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                DialogButton { buttonText: qsTr("Close"); onClicked: root.dismiss() }
                DialogButton {
                    buttonText: qsTr("Capture")
                    onClicked: {
                        const rect = initial.checked && initial.enabled ? {
                            x: regionFields.itemAt(0).value,
                            y: regionFields.itemAt(1).value,
                            width: regionFields.itemAt(2).value,
                            height: regionFields.itemAt(3).value
                        } : null
                        const id = root.owner.requestCapture({ target: ["active", "monitor", "desktop"][target.currentIndex],
                            monitor: monitor.currentText, delay: delay.value,
                            selection: ["region", "all", "last"][selection.currentIndex], region: rect,
                            edit: edit.checked, concurrent: concurrent.checked, acceptOnSelection: quick.checked })
                        if (id) root.dismiss()
                        else root.errorMessage = root.owner.lastError
                    }
                }
            }
        }
    }
}
