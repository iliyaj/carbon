import "root:/Services"
import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root
    required property var scopeRoot
    anchors.fill: parent
    property var tabButtonList: [
        {"icon": "apps", "name": qsTr("Apps")}
    ]
    property int selectedTab: 0

    function focusActiveItem() {
        swipeView.currentItem.forceActiveFocus()
    }

    Keys.onPressed: (event) => {
        if (event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown) {
                root.selectedTab = Math.min(root.selectedTab + 1, root.tabButtonList.length - 1)
                event.accepted = true;
            }
            else if (event.key === Qt.Key_PageUp) {
                root.selectedTab = Math.max(root.selectedTab - 1, 0)
                event.accepted = true;
            }
            else if (event.key === Qt.Key_Tab) {
                root.selectedTab = (root.selectedTab + 1) % root.tabButtonList.length;
                event.accepted = true;
            }
            else if (event.key === Qt.Key_Backtab) {
                root.selectedTab = (root.selectedTab - 1 + root.tabButtonList.length) % root.tabButtonList.length;
                event.accepted = true;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: sidebarPadding

        spacing: sidebarPadding

        PrimaryTabBar { // Tab strip
            id: tabBar
            tabButtonList: root.tabButtonList
            externalTrackedTab: root.selectedTab
            function onCurrentIndexChanged(currentIndex) {
                root.selectedTab = currentIndex
            }
        }

        SwipeView { // Content pages
            id: swipeView
            Layout.topMargin: 5
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            currentIndex: tabBar.externalTrackedTab
            onCurrentIndexChanged: {
                tabBar.enableIndicatorAnimation = true
                root.selectedTab = currentIndex
            }

            clip: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: swipeView.width
                    height: swipeView.height
                    radius: Appearance.rounding.small
                }
            }

            contentChildren: [
                appDrawer.createObject()
            ]
        }

        Component {
            id: appDrawer
            AppDrawer {}
        }
        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: 32
            implicitWidth: 32
            buttonRadius: Appearance.rounding.full
            colBackground: root.scopeRoot.detach ? Appearance.m3colors.m3primary : "transparent"
            colBackgroundHover: root.scopeRoot.detach ? Appearance.m3colors.m3primary : Appearance.colors.colLayer2Hover
            onClicked: root.scopeRoot.detach = !root.scopeRoot.detach

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "push_pin"
                iconSize: Appearance.font.pixelSize.normal
                color: root.scopeRoot.detach ? Appearance.m3colors.m3onPrimary : Appearance.colors.colSubtext
            }
        }

    }
}
