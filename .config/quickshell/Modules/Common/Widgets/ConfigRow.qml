import QtQuick
import QtQuick.Layouts
import "root:/Modules/Common/"

RowLayout {
    property bool uniform: false
    spacing: Appearance.spacing.md
    uniformCellSizes: uniform
}
