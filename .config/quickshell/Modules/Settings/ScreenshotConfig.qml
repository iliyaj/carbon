pragma ComponentBehavior: Bound

import qs.Modules.Common
import qs.Modules.Common.Widgets
import qs.Services
import "../ScreenCapture/screenshot_preferences.js" as ScreenshotPreferences
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs as NativeDialogs
import QtQuick.Layouts

ContentPage {
    id: root
    forceWidth: true
    property string errorMessage: ""
    readonly property var toolLabels: ({
        select: qsTr("Select, move and resize"), pen: qsTr("Freehand pen"),
        line: qsTr("Straight line"), arrow: qsTr("Arrow"),
        rect: qsTr("Outline rectangle"), fill: qsTr("Filled rectangle"),
        ellipse: qsTr("Ellipse"), marker: qsTr("Highlighter"),
        text: qsTr("Text"), counter: qsTr("Numbered pointer"),
        conceal: qsTr("Conceal"), pixelate: qsTr("Pixelate"),
        blur: qsTr("Blur"), solid: qsTr("Solid redaction"), invert: qsTr("Invert colours")
    })

    component RoundedField: TextField {
        id: input
        implicitHeight: 44
        leftPadding: Appearance.spacing.md
        rightPadding: Appearance.spacing.md
        color: Appearance.colors.colOnLayer2
        selectionColor: Appearance.colors.colSecondaryContainer
        selectedTextColor: Appearance.colors.colOnSecondaryContainer
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        selectByMouse: true
        background: Rectangle {
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2
            border.width: input.activeFocus ? 2 : 1
            border.color: input.activeFocus ? Appearance.m3colors.m3primary : Appearance.m3colors.m3outlineVariant
        }
    }

    component ColourButton: RippleButton {
        id: colourButton
        required property color swatchColour
        property string label: ""
        implicitWidth: label.length > 0 ? swatchContent.implicitWidth + 24 : 44
        implicitHeight: 44
        buttonRadius: 22
        colBackground: Appearance.colors.colLayer2
        Accessible.name: label.length > 0 ? label : qsTr("Edit colour %1").arg(swatchColour)
        contentItem: RowLayout {
            id: swatchContent
            spacing: Appearance.spacing.sm
            Rectangle {
                Layout.alignment: Qt.AlignCenter
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                color: colourButton.swatchColour
                border.width: 1
                border.color: Appearance.m3colors.m3outline
            }
            StyledText {
                visible: colourButton.label.length > 0
                text: colourButton.label
                color: Appearance.colors.colOnLayer2
            }
        }
        StyledToolTip { content: colourButton.swatchColour.toString().toUpperCase() }
    }

    function chooseColour(key: string, index: int): void {
        colourDialog.preferenceKey = key;
        colourDialog.paletteIndex = index;
        colourDialog.selectedColor = key === "color" ? ConfigOptions.screenshot.color
            : index >= 0 ? ConfigOptions.screenshot.palette[index] : ConfigOptions.screenshot.color;
        colourDialog.open();
    }

    NativeDialogs.ColorDialog {
        id: colourDialog
        property string preferenceKey: "color"
        property int paletteIndex: -1
        title: preferenceKey === "color" ? qsTr("Drawing colour") : qsTr("Palette colour")
        onAccepted: {
            const colour = selectedColor.toString();
            if (preferenceKey === "color") {
                root.setValue("color", colour);
            } else {
                const palette = ConfigOptions.screenshot.palette.slice();
                if (paletteIndex < 0) palette.push(colour);
                else if (paletteIndex < palette.length) palette[paletteIndex] = colour;
                root.setValue("palette", palette);
            }
        }
    }

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
                    StyledText {
                        visible: !["bool", "tools"].includes(fieldRow.modelData.type)
                        text: fieldRow.modelData.type === "palette" ? qsTr("Palette")
                            : fieldRow.modelData.type === "color" ? qsTr("Drawing colour") : fieldRow.modelData.label
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                    ContentSubsection {
                        visible: fieldRow.modelData.type === "tools"
                        title: qsTr("Visible tools")
                        tooltip: qsTr("Choose which tools appear in the screenshot editor. At least one tool must stay enabled. Newly enabled tools are added to the end of the toolbar.")
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            uniformCellWidths: true
                            columnSpacing: Appearance.spacing.md
                            rowSpacing: 0
                            Repeater {
                                model: fieldRow.modelData.type === "tools" ? ScreenshotPreferences.tools : []
                                delegate: ConfigSwitch {
                                    required property string modelData
                                    text: root.toolLabels[modelData]
                                    checked: ConfigOptions.screenshot.toolOrder.includes(modelData)
                                    enabled: !checked || ConfigOptions.screenshot.toolOrder.length > 1
                                    onClicked: {
                                        const order = ConfigOptions.screenshot.toolOrder;
                                        root.setValue("toolOrder", order.includes(modelData)
                                            ? order.filter(tool => tool !== modelData) : order.concat([modelData]));
                                    }
                                }
                            }
                        }
                    }
                    ConfigSwitch {
                        visible: fieldRow.modelData.type === "bool"
                        text: fieldRow.modelData.label
                        checked: ConfigOptions.screenshot[fieldRow.modelData.key] === true
                        onClicked: root.setValue(fieldRow.modelData.key, !ConfigOptions.screenshot[fieldRow.modelData.key])
                    }
                    StyledSpinBox {
                        visible: fieldRow.modelData.type === "int"
                        from: fieldRow.modelData.min ?? 0; to: fieldRow.modelData.max ?? 100
                        editable: true
                        value: visible ? ConfigOptions.screenshot[fieldRow.modelData.key] : 0
                        onValueChanged: {
                            if (visible && value !== ConfigOptions.screenshot[fieldRow.modelData.key])
                                root.setValue(fieldRow.modelData.key, value);
                        }
                    }
                    StyledComboBox {
                        Layout.fillWidth: true
                        visible: fieldRow.modelData.choices !== undefined
                        model: fieldRow.modelData.choices ?? []
                        currentIndex: model.indexOf(ConfigOptions.screenshot[fieldRow.modelData.key])
                        onActivated: index => root.setValue(fieldRow.modelData.key, model[index])
                    }
                    ColourButton {
                        visible: fieldRow.modelData.type === "color"
                        swatchColour: ConfigOptions.screenshot.color
                        label: qsTr("Choose colour")
                        onClicked: root.chooseColour("color", -1)
                    }
                    Flow {
                        Layout.fillWidth: true
                        visible: fieldRow.modelData.type === "palette"
                        spacing: Appearance.spacing.sm
                        Repeater {
                            model: fieldRow.modelData.type === "palette" ? ConfigOptions.screenshot.palette : []
                            delegate: Item {
                                id: paletteSwatch
                                required property string modelData
                                required property int index
                                width: 52
                                height: 52
                                ColourButton {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    swatchColour: paletteSwatch.modelData
                                    onClicked: root.chooseColour("palette", paletteSwatch.index)
                                }
                                RippleButton {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    buttonRadius: 10
                                    colBackground: Appearance.colors.colLayer2
                                    enabled: ConfigOptions.screenshot.palette.length > 1
                                    Accessible.name: qsTr("Remove colour %1").arg(paletteSwatch.modelData)
                                    contentItem: MaterialSymbol {
                                        text: "close"
                                        iconSize: 14
                                        color: Appearance.colors.colOnLayer2
                                    }
                                    onClicked: {
                                        const palette = ConfigOptions.screenshot.palette.slice();
                                        palette.splice(paletteSwatch.index, 1);
                                        root.setValue("palette", palette);
                                    }
                                    StyledToolTip { content: qsTr("Remove colour") }
                                }
                            }
                        }
                        Item {
                            width: 44
                            height: 52
                            RippleButton {
                                anchors.bottom: parent.bottom
                                width: 44
                                height: 44
                                buttonRadius: 22
                                colBackground: Appearance.colors.colLayer2
                                enabled: ConfigOptions.screenshot.palette.length < 32
                                Accessible.name: qsTr("Add colour")
                                contentItem: MaterialSymbol {
                                    text: "add"
                                    iconSize: 24
                                    horizontalAlignment: Text.AlignHCenter
                                    color: Appearance.colors.colOnLayer2
                                }
                                onClicked: root.chooseColour("palette", -1)
                                StyledToolTip { content: qsTr("Add colour") }
                            }
                        }
                    }
                    RoundedField {
                        Layout.fillWidth: true
                        visible: !["bool", "int", "tools", "palette", "color"].includes(fieldRow.modelData.type) && fieldRow.modelData.choices === undefined
                        text: String(ConfigOptions.screenshot[fieldRow.modelData.key])
                        selectByMouse: true
                        onEditingFinished: {
                            try {
                                const value = fieldRow.modelData.type === "real" ? Number(text) : text;
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
        RippleButtonWithIcon {
            materialIcon: "restart_alt"
            mainText: qsTr("Reset shortcuts")
            onClicked: root.setValue("shortcuts", {})
        }
        Repeater {
            model: Object.keys(ScreenshotPreferences.shortcuts)
            delegate: RowLayout {
                id: shortcutRow
                required property string modelData
                Layout.fillWidth: true
                StyledText { Layout.fillWidth: true; text: shortcutRow.modelData }
                RoundedField {
                    Layout.preferredWidth: 200
                    text: ScreenshotPreferences.bindings(ConfigOptions.screenshot.shortcuts)[shortcutRow.modelData]
                    selectByMouse: true
                    onEditingFinished: root.setValue("shortcuts", Object.assign({}, ConfigOptions.screenshot.shortcuts, { [shortcutRow.modelData]: text }))
                }
            }
        }
    }
}
