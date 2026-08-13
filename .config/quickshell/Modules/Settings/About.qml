import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "root:/Services/"
import "root:/Modules/Common/"
import "root:/Modules/Common/Widgets/"

ContentPage {
    forceWidth: true

    ContentSection {
        title: "Distro"

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            IconImage {
                implicitSize: 100
                source: Quickshell.iconPath(SystemInfo.logo)
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                // spacing: 10
                StyledText {
                    text: SystemInfo.distroName
                    font.pixelSize: Appearance.font.pixelSize.title
                }
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.normal
                    text: SystemInfo.homeUrl
                    textFormat: Text.MarkdownText
                    onLinkActivated: (link) => {
                        Qt.openUrlExternally(link)
                    }
                    PointingHandLinkHover {}
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 5

            RippleButtonWithIcon {
                materialIcon: "auto_stories"
                mainText: "Documentation"
                onClicked: {
                    Qt.openUrlExternally(SystemInfo.documentationUrl)
                }
            }
            RippleButtonWithIcon {
                materialIcon: "support"
                mainText: "Help & Support"
                onClicked: {
                    Qt.openUrlExternally(SystemInfo.supportUrl)
                }
            }
            RippleButtonWithIcon {
                materialIcon: "bug_report"
                mainText: "Report a Bug"
                onClicked: {
                    Qt.openUrlExternally(SystemInfo.bugReportUrl)
                }
            }
            RippleButtonWithIcon {
                materialIcon: "policy"
                materialIconFill: false
                mainText: "Privacy Policy"
                onClicked: {
                    Qt.openUrlExternally(SystemInfo.privacyPolicyUrl)
                }
            }

        }

    }
    ContentSection {
        title: "Carbon"

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            MaterialSymbol {
                iconSize: 70
                text: "files"
                color: Appearance.colors.colOnSecondaryContainer
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                // spacing: 10
                StyledText {
                    text: "Carbon"
                    font.pixelSize: Appearance.font.pixelSize.title
                }
                StyledText {
                    text: "https://github.com/iliyaj/carbon"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    textFormat: Text.MarkdownText
                    onLinkActivated: (link) => {
                        Qt.openUrlExternally(link)
                    }
                    PointingHandLinkHover {}
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 5

            RippleButtonWithIcon {
                materialIcon: "auto_stories"
                mainText: "Documentation"
                onClicked: {
                    Qt.openUrlExternally("https://github.com/iliyaj/carbon/blob/main/README.md")
                }
            }
            RippleButtonWithIcon {
                materialIcon: "adjust"
                materialIconFill: false
                mainText: "Issues"
                onClicked: {
                    Qt.openUrlExternally("https://github.com/iliyaj/carbon/issues")
                }
            }
            RippleButtonWithIcon {
                materialIcon: "forum"
                mainText: "Discussions"
                onClicked: {
                    Qt.openUrlExternally("https://github.com/iliyaj/carbon/discussions")
                }
            }
            RippleButtonWithIcon {
                materialIcon: "fork_right"
                mainText: "Upstream"
                onClicked: {
                    Qt.openUrlExternally("https://github.com/end-4/dots-hyprland")
                }
            }


        }
    }
}
