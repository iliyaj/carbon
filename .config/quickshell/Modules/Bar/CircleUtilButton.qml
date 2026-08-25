import "root:/Modules/Common"
import "root:/Modules/Common/Widgets/"
import "root:/Modules/Common/Functions"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RippleButton {
    id: button

    required default property Item content
    property bool extraActiveCondition: false

    implicitHeight: Math.max(content.implicitHeight, 26, content.implicitHeight)
    implicitWidth: implicitHeight
    contentItem: content

}
