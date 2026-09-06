import QtQuick
import QtQuick.Layouts
import qs.Modules.Common

RowLayout {
    property bool uniform: false
    spacing: Appearance.spacing.md
    uniformCellSizes: uniform
}
