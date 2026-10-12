pragma ComponentBehavior: Bound

import qs.Modules.Common
import qs.Modules.Common.Widgets
import qs.Services
import "../ScreenCapture/screenshot_preferences.js" as ScreenshotPreferences
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ContentPage {
    id: root
    forceWidth: true
    property string errorMessage: ""

    function setValue(key, value): void {
        try {
            ScreenshotPreferences.validate({ [key]: value });
            ConfigLoader.setConfigValueAndSave("screenshot." + key, value);
            errorMessage = "";
        } catch (error) { errorMessage = error.message; }
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Capture, annotation and export preferences. Global keys are configured in Hyprland. Empty local shortcuts disable that action; Reset restores the defaults.")
        wrapMode: Text.WordWrap
    }
    StyledText {
        Layout.fillWidth: true
        visible: root.errorMessage.length > 0
        text: root.errorMessage
        color: Appearance.m3colors.m3error
        wrapMode: Text.WordWrap
    }
    Repeater {
        model: ["Tools", "Text", "Capture", "Output", "Appearance", "Precision"]
        delegate: ContentSection {
            id: section
            required property string modelData
            title: modelData
            Repeater {
                model: ScreenshotPreferences.fields.filter(field => field.group === section.modelData)
                delegate: ColumnLayout {
                    id: fieldRow
                    required property var modelData
                    Layout.fillWidth: true
                    StyledText { text: fieldRow.modelData.label; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    CheckBox {
                        visible: fieldRow.modelData.type === "bool"
                        checked: ConfigOptions.screenshot[fieldRow.modelData.key] === true
                        onToggled: root.setValue(fieldRow.modelData.key, checked)
                    }
                    SpinBox {
                        visible: fieldRow.modelData.type === "int"
                        from: fieldRow.modelData.min ?? 0; to: fieldRow.modelData.max ?? 100
                        editable: true
                        value: visible ? ConfigOptions.screenshot[fieldRow.modelData.key] : 0
                        onValueModified: root.setValue(fieldRow.modelData.key, value)
                    }
                    ComboBox {
                        Layout.fillWidth: true
                        visible: fieldRow.modelData.choices !== undefined
                        model: fieldRow.modelData.choices ?? []
                        currentIndex: model.indexOf(ConfigOptions.screenshot[fieldRow.modelData.key])
                        onActivated: index => root.setValue(fieldRow.modelData.key, model[index])
                    }
                    TextField {
                        Layout.fillWidth: true
                        visible: !["bool", "int"].includes(fieldRow.modelData.type) && fieldRow.modelData.choices === undefined
                        text: ["palette", "tools"].includes(fieldRow.modelData.type)
                            ? JSON.stringify(ConfigOptions.screenshot[fieldRow.modelData.key]) : String(ConfigOptions.screenshot[fieldRow.modelData.key])
                        selectByMouse: true
                        onEditingFinished: {
                            try {
                                const value = ["palette", "tools"].includes(fieldRow.modelData.type) ? JSON.parse(text)
                                    : fieldRow.modelData.type === "real" ? Number(text) : text;
                                root.setValue(fieldRow.modelData.key, value);
                            } catch (error) { root.errorMessage = error.message; }
                        }
                    }
                }
            }
        }
    }
    ContentSection {
        title: qsTr("Local shortcuts")
        Button { text: qsTr("Reset shortcuts"); onClicked: root.setValue("shortcuts", {}) }
        Repeater {
            model: Object.keys(ScreenshotPreferences.shortcuts)
            delegate: RowLayout {
                id: shortcutRow
                required property string modelData
                Layout.fillWidth: true
                StyledText { Layout.fillWidth: true; text: shortcutRow.modelData }
                TextField {
                    Layout.preferredWidth: 200
                    text: ScreenshotPreferences.bindings(ConfigOptions.screenshot.shortcuts)[shortcutRow.modelData]
                    selectByMouse: true
                    onEditingFinished: root.setValue("shortcuts", Object.assign({}, ConfigOptions.screenshot.shortcuts, { [shortcutRow.modelData]: text }))
                }
            }
        }
    }
}
