import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Modules.Common
import qs.Modules.Common.Widgets

ColumnLayout { // Window content with navigation rail and content pane
    id: root
    property bool expanded: true
    property int currentIndex: 0
    spacing: Appearance.spacing.sm
}
