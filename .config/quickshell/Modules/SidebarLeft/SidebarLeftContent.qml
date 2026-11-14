import qs.Services
import qs.Modules.Common
import qs.Modules.Common.Widgets
import qs.Modules.Archfit
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property var scopeRoot
    property int selectedTab: 0
    property var tabButtonList: [
        {"icon": "apps", "name": qsTr("Apps")},
        {"icon": "ecg", "name": qsTr("Archfit")}
    ]
    anchors.fill: parent
    function focusActiveItem() {
        if (root.selectedTab === 0)
            appDrawer.forceActiveFocus()
        else
            archfitPanel.forceActiveFocus()
    }
    onSelectedTabChanged: focusActiveItem()

    Keys.onPressed: (event) => {
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_Tab) {
                root.selectedTab = (root.selectedTab + 1) % root.tabButtonList.length
                event.accepted = true
            } else if (event.key === Qt.Key_Backtab) {
                root.selectedTab = (root.selectedTab - 1 + root.tabButtonList.length) % root.tabButtonList.length
                event.accepted = true
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.scopeRoot.sidebarPadding

        spacing: root.scopeRoot.sidebarPadding

        PrimaryTabBar {
            tabButtonList: root.tabButtonList
            externalTrackedTab: root.selectedTab
            function onCurrentIndexChanged(index) {
                root.selectedTab = index
            }
        }

        StackLayout {
            Layout.topMargin: 5
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.selectedTab

            AppDrawer {
                id: appDrawer
                clip: true
            }

            ArchfitPanel {
                id: archfitPanel
                clip: true
            }
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
