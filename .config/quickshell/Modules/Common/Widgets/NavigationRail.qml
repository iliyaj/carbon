import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "root:/Modules/Common/"
import "root:/Modules/Common/Widgets/"

ColumnLayout { // Window content with navigation rail and content pane
    id: root
    property bool expanded: true
    property int currentIndex: 0
    spacing: Appearance.spacing.sm
}
