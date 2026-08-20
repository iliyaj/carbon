import "root:/Services"
import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Cheatsheet keybind view. Renders HyprlandKeybinds.sections, which arrive
 * already grouped and with modifiers resolved -- this file only lays them out.
 *
 * Sections used to be a two-level tree (an unnamed root column containing
 * columns containing sections), because get_keybinds.py mirrored the `#!` /
 * `##!` comment nesting. Categories are flat now, so a Flow wraps them into
 * columns by itself.
 */
Item {
    id: root
    property real spacing: 20
    property real titleSpacing: 7
    property real maximumWidth: 0
    property real maximumHeight: 0
    implicitWidth: Math.min(maximumWidth, flow.implicitWidth + Appearance.rounding.small * 2)
    implicitHeight: maximumHeight

    property var keyBlacklist: ["Super_L"]
    property var keySubstitutions: ({
        "Super": "󰖳",
        "mouse_up": "Scroll ↓",    // ikr, weird
        "mouse_down": "Scroll ↑",  // trust me bro
        "mouse:272": "LMB",
        "mouse:273": "RMB",
        "mouse:275": "MouseBack",
        "Slash": "/",
        "Hash": "#",
        "Return": "Enter",
    })

    function pretty(key: string): string {
        return root.keySubstitutions[key] ?? key;
    }

    function flattenBinds(binds: var): var {
        const entries = [];
        for (let i = 0; i < binds.length; i++) {
            entries.push({ isKeys: true, bind: binds[i] });
            entries.push({ isKeys: false, bind: binds[i] });
        }
        return entries;
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        anchors.margins: Appearance.rounding.small
        clip: true
        contentWidth: Math.max(width, flow.implicitWidth)
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.horizontal: ScrollBar {
            policy: flickable.contentWidth > flickable.width
                ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        Flow {
            id: flow
            height: flickable.height
            flow: Flow.TopToBottom
            spacing: root.spacing

            Repeater {
                model: HyprlandKeybinds.sections

                delegate: ColumnLayout {
                    id: section
                    required property var modelData
                    spacing: root.titleSpacing

                    StyledText {
                        font.family: Appearance.font.family.title
                        font.pixelSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colOnLayer0
                        text: section.modelData.name
                    }

                    GridLayout {
                        columns: 2

                        Repeater {
                            // A GridLayout delegate can only produce one item, so each
                            // bind becomes two entries: its keys, then its label.
                            model: root.flattenBinds(section.modelData.binds)

                            delegate: Loader {
                                required property var modelData
                                sourceComponent: modelData.isKeys ? keysRow : labelText

                                Component {
                                    id: keysRow
                                    RowLayout {
                                        spacing: 4
                                        Repeater {
                                            model: modelData.bind.mods
                                            delegate: KeyboardKey {
                                                required property var modelData
                                                key: root.pretty(modelData)
                                            }
                                        }
                                        StyledText {
                                            visible: modelData.bind.mods.length > 0
                                                && !root.keyBlacklist.includes(modelData.bind.key)
                                            Layout.alignment: Qt.AlignVCenter
                                            text: "+"
                                        }
                                        KeyboardKey {
                                            visible: !root.keyBlacklist.includes(modelData.bind.key)
                                            key: root.pretty(modelData.bind.key)
                                            color: Appearance.colors.colOnLayer0
                                        }
                                    }
                                }

                                Component {
                                    id: labelText
                                    StyledText {
                                        leftPadding: 8
                                        rightPadding: 8
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        text: modelData.bind.label
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
