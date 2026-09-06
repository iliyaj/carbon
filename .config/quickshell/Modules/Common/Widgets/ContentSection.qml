import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Modules.Common
import qs.Modules.Common.Widgets

ColumnLayout {
    id: root
    property string title
    default property alias data: sectionContent.data

    Layout.fillWidth: true
    spacing: Appearance.spacing.sm
    StyledText {
        text: root.title
        font.pixelSize: Appearance.font.pixelSize.larger
        font.weight: Font.Medium
    }
    ColumnLayout {
        id: sectionContent
        Layout.fillWidth: true
        spacing: Appearance.spacing.md
    }
}
