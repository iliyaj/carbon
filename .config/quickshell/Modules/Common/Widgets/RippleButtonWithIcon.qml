import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Modules.Common
import qs.Modules.Common.Widgets

RippleButton {
    id: buttonWithIconRoot
    property string nerdIcon
    property string materialIcon
    property bool materialIconFill: true
    property string mainText: "Button text"
    property Component mainContentComponent: Component {
        StyledText {
            text: buttonWithIconRoot.mainText
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer2
        }
    }
    implicitHeight: 35
    horizontalPadding: 15
    buttonRadius: Appearance.rounding.small
    colBackground: Appearance.colors.colLayer2

    contentItem: RowLayout {
        Item {
            implicitWidth: Math.max(materialIconLoader.implicitWidth, nerdIconLoader.implicitWidth)
            Loader {
                id: materialIconLoader
                anchors.centerIn: parent
                active: !nerdIcon
                sourceComponent: MaterialSymbol {
                    text: buttonWithIconRoot.materialIcon
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer2
                    fill: buttonWithIconRoot.materialIconFill ? 1 : 0
                }
            }
            Loader {
                id: nerdIconLoader
                anchors.centerIn: parent
                active: nerdIcon
                sourceComponent: StyledText {
                    text: buttonWithIconRoot.nerdIcon
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.family: Appearance.font.family.iconNerd
                    color: Appearance.colors.colOnLayer2
                }
            }
        }
        Loader {
            sourceComponent: buttonWithIconRoot.mainContentComponent
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
