import qs.Services
import qs.Modules.Common
import qs.Modules.Common.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property var scopeRoot
    anchors.fill: parent
    function focusActiveItem() {
        appDrawer.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.scopeRoot.sidebarPadding

        spacing: root.scopeRoot.sidebarPadding

        PrimaryTabBar {
            tabButtonList: [{"icon": "apps", "name": qsTr("Apps")}]
            externalTrackedTab: 0
            // PrimaryTabBar calls this callback even when there is only one tab.
            function onCurrentIndexChanged(index) {}
        }

        AppDrawer {
            id: appDrawer
            Layout.topMargin: 5
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
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
