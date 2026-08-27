import "root:/Services/"
import "root:/Modules/Common"
import "root:/Modules/Common/Widgets"
import "root:/Modules/Common/Functions"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property string searchingText: ""
    property int itemsPerRow: 4
    property real itemSize: 70
    property real itemSpacing: 10
    property real gridWidth: (itemSize + itemSpacing) * itemsPerRow
    property bool searching: searchingText.length > 0

    // Right-click context menu state
    property var menuEntry: null
    property real menuX: 0
    property real menuY: 0

    function forceActiveFocus() {
        searchInput.forceActiveFocus()
    }

    function openAppMenu(entry, sourceItem, mx, my) {
        const pos = sourceItem.mapToItem(root, mx, my)
        root.menuX = pos.x
        root.menuY = pos.y
        root.menuEntry = entry
    }

    function entryPinId(entry): string {
        return (entry?.id ?? "").replace(/\.desktop$/, "")
    }

    function entryIsPinned(entry): bool {
        const id = entryPinId(entry).toLowerCase()
        const pinned = ConfigOptions?.dock.pinnedApps ?? []
        return pinned.some(p => p.toLowerCase() === id)
    }

    function togglePinned(entry) {
        const id = entryPinId(entry)
        const pinned = Array.from(ConfigOptions?.dock.pinnedApps ?? [])
        const index = pinned.findIndex(p => p.toLowerCase() === id.toLowerCase())
        if (index >= 0) {
            pinned.splice(index, 1)
        } else {
            pinned.push(id)
        }
        ConfigLoader.setConfigValueAndSave("dock.pinnedApps", pinned)
    }

    function togglePinnedToTop(entry) {
        const id = AppSearch.entryId(entry)
        const pinned = Array.from(ConfigOptions?.appDrawer.pinnedApps ?? [])
            .filter(p => p.length > 0)
        const index = pinned.findIndex(p => p.toLowerCase() === id)
        if (index >= 0) {
            pinned.splice(index, 1)
        } else {
            pinned.push(id)
        }
        ConfigLoader.setConfigValueAndSave("appDrawer.pinnedApps", pinned)
    }

    function toggleHidden(entry) {
        const id = AppSearch.entryId(entry)
        const hidden = Array.from(ConfigOptions?.appDrawer.hiddenApps ?? [])
            .filter(h => h.length > 0)
        const index = hidden.findIndex(h => h.toLowerCase() === id)
        if (index >= 0) {
            hidden.splice(index, 1)
        } else {
            hidden.push(id)
        }
        ConfigLoader.setConfigValueAndSave("appDrawer.hiddenApps", hidden)
    }

    // category === null clears the override, falling back to Categories= rules
    function setCategoryOverride(entry, category) {
        const id = AppSearch.entryId(entry)
        const overrides = Object.assign({}, ConfigOptions?.appDrawer.categoryOverrides ?? {})
        if (category === null) {
            delete overrides[id]
        } else {
            overrides[id] = category
        }
        ConfigLoader.setConfigValueAndSave("appDrawer.categoryOverrides", overrides)
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape && root.menuEntry !== null) {
            root.menuEntry = null
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Escape) {
            searchInput.text = ""
            searchInput.forceActiveFocus()
            event.accepted = true
        }

        if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 0x20) {
            if (!searchInput.activeFocus) {
                searchInput.forceActiveFocus()
                searchInput.text = searchInput.text + event.text
                event.accepted = true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            searchInput.text = ""
            searchInput.focus = false
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            anchors.topMargin: 5
            anchors.bottomMargin: 25
            spacing: 15

        // Search bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 45
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer1
            border.color: searchInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
            border.width: 0.5

            Behavior on border.color {
                ColorAnimation { duration: 200 }
            }

            RowLayout {
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 10

                MaterialSymbol {
                    iconSize: 20
                    color: Appearance.colors.colOnLayer1
                    text: "search"
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 0
                }

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    placeholderText: qsTr("Search apps...")
                    placeholderTextColor: Appearance.colors.colOnLayer1Inactive
                    color: Appearance.colors.colOnLayer1
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    horizontalAlignment: Text.AlignHCenter
                    background: null

                    onTextChanged: {
                        root.searchingText = text
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Down) {
                            if (root.searching && appGrid.count > 0) {
                                appGrid.currentIndex = 0
                                appGrid.forceActiveFocus()
                                event.accepted = true
                            }
                        }
                    }
                }

                MaterialSymbol {
                    visible: searchInput.text.length > 0
                    iconSize: 18
                    color: Appearance.colors.colOnLayer1
                    text: "close"
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 20

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchInput.text = ""
                            searchInput.forceActiveFocus()
                        }
                    }
                }
            }
        }

        // Apps area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Categorized view (Apple App Library style), shown while not searching
            ScrollView {
                id: categoryView
                visible: !root.searching

                // Content instantiation while the sidebar is hidden can drift the
                // scroll position, so snap back to the top on every open
                Connections {
                    target: GlobalStates
                    function onSidebarLeftOpenChanged() {
                        if (GlobalStates.sidebarLeftOpen) {
                            categoryView.contentItem.contentY = 0
                            AppSearch.revealHidden = false
                        }
                    }
                }
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, root.gridWidth)
                height: parent.height
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.vertical.contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: "transparent"
                }

                Column {
                    width: root.gridWidth
                    spacing: 12

                    Repeater {
                        model: AppSearch.groupedList

                        delegate: Column {
                            id: section
                            required property var modelData
                            width: parent.width
                            spacing: 6

                            // Section header
                            RowLayout {
                                width: parent.width - 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8

                                MaterialSymbol {
                                    iconSize: 17
                                    color: Appearance.colors.colPrimary
                                    text: section.modelData.icon
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                StyledText {
                                    text: section.modelData.name
                                    color: Appearance.colors.colOnLayer1
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.family: Appearance.font.family.main
                                    font.weight: Font.DemiBold
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitHeight: 1
                                    color: Appearance.colors.colOutlineVariant
                                }

                                StyledText {
                                    text: section.modelData.apps.length
                                    color: Appearance.colors.colOnLayer1Inactive
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.family: Appearance.font.family.main
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            // Section apps
                            Grid {
                                columns: root.itemsPerRow
                                anchors.horizontalCenter: parent.horizontalCenter

                                Repeater {
                                    model: section.modelData.apps

                                    delegate: AppDrawerButton {
                                        id: sectionAppButton
                                        required property var modelData
                                        entry: modelData
                                        itemSize: root.itemSize
                                        width: root.itemSize + root.itemSpacing
                                        height: root.itemSize + 25 + root.itemSpacing
                                        onMenuRequested: (mx, my) => root.openAppMenu(entry, sectionAppButton, mx, my)
                                    }
                                }
                            }
                        }
                    }

                    // Reveal toggle for hidden apps
                    StyledText {
                        visible: AppSearch.revealHidden || AppSearch.hiddenCount > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: AppSearch.revealHidden
                            ? qsTr("Done showing hidden apps")
                            : StringUtils.format(qsTr("Show hidden apps ({0})"), AppSearch.hiddenCount)
                        color: Appearance.colors.colOnLayer1Inactive
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.main

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AppSearch.revealHidden = !AppSearch.revealHidden
                        }
                    }
                }
            }

            // Flat grid for search results
            ScrollView {
                visible: root.searching
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, root.gridWidth)
                height: parent.height
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.vertical.contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: "transparent"
                }

                GridView {
                    id: appGrid
                    width: root.gridWidth
                    cellWidth: root.itemSize + root.itemSpacing
                    cellHeight: root.itemSize + 25 + root.itemSpacing
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: -1

                    onModelChanged: {
                        currentIndex = -1
                    }

                    model: root.searching ? AppSearch.fuzzyQuery(root.searchingText) : []

                    delegate: Item {
                        id: appItem
                        required property var modelData
                        width: appGrid.cellWidth
                        height: appGrid.cellHeight

                        AppDrawerButton {
                            id: appButton
                            anchors.fill: parent
                            entry: appItem.modelData
                            itemSize: root.itemSize
                            onMenuRequested: (mx, my) => root.openAppMenu(entry, appButton, mx, my)
                        }

                        // Keyboard navigation
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                appButton.launch()
                                event.accepted = true
                            }
                            if (event.key === Qt.Key_Up && appGrid.currentIndex >= root.itemsPerRow) {
                                appGrid.currentIndex -= root.itemsPerRow
                                event.accepted = true
                            }
                            if (event.key === Qt.Key_Down && appGrid.currentIndex < appGrid.count - root.itemsPerRow) {
                                appGrid.currentIndex += root.itemsPerRow
                                event.accepted = true
                            }
                            if (event.key === Qt.Key_Left && appGrid.currentIndex > 0) {
                                appGrid.currentIndex -= 1
                                event.accepted = true
                            }
                            if (event.key === Qt.Key_Right && appGrid.currentIndex < appGrid.count - 1) {
                                appGrid.currentIndex += 1
                                event.accepted = true
                            }
                            if (event.key === Qt.Key_Escape) {
                                searchInput.forceActiveFocus()
                                event.accepted = true
                            }
                        }
                    }

                    // Grid focus highlight
                    highlight: Rectangle {
                        color: Appearance.colors.colPrimary
                        opacity: 0.2
                        radius: Appearance.rounding.normal

                        Behavior on x { NumberAnimation { duration: 100 } }
                        Behavior on y { NumberAnimation { duration: 100 } }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Up && appGrid.currentIndex < root.itemsPerRow) {
                            searchInput.forceActiveFocus()
                            event.accepted = true
                        }
                    }
                }
            }
        }
        }
    }

    // Right-click context menu for an app tile
    Loader {
        id: appMenuLoader
        anchors.fill: parent
        active: root.menuEntry !== null

        sourceComponent: Item {
            id: menuOverlay
            // When true the menu shows the category picker instead of the main entries
            property bool pickingCategory: false

            Connections {
                target: GlobalStates
                function onSidebarLeftOpenChanged() {
                    if (!GlobalStates.sidebarLeftOpen) root.menuEntry = null
                }
            }

            // Click outside to close
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onPressed: root.menuEntry = null
            }

            StyledRectangularShadow {
                target: appMenu
            }
            Rectangle {
                id: appMenu
                x: Math.max(4, Math.min(root.menuX, root.width - width - 4))
                y: Math.max(4, Math.min(root.menuY, root.height - height - 4))
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainer
                implicitHeight: appMenuColumnLayout.implicitHeight + radius * 2
                implicitWidth: appMenuColumnLayout.implicitWidth

                ColumnLayout {
                    id: appMenuColumnLayout
                    anchors.centerIn: parent
                    spacing: 0

                    MenuButton {
                        visible: !menuOverlay.pickingCategory
                        Layout.fillWidth: true
                        buttonText: qsTr("Launch")
                        onClicked: {
                            const entry = root.menuEntry
                            root.menuEntry = null
                            AppLauncher.launchDesktopEntry(entry)
                        }
                    }

                    MenuButton {
                        visible: !menuOverlay.pickingCategory
                        Layout.fillWidth: true
                        buttonText: AppSearch.isPinnedToTop(root.menuEntry)
                            ? qsTr("Unpin from top") : qsTr("Pin to top")
                        onClicked: {
                            const entry = root.menuEntry
                            root.menuEntry = null
                            root.togglePinnedToTop(entry)
                        }
                    }

                    MenuButton {
                        visible: !menuOverlay.pickingCategory
                        Layout.fillWidth: true
                        buttonText: root.entryIsPinned(root.menuEntry)
                            ? qsTr("Unpin from dock") : qsTr("Pin to dock")
                        onClicked: {
                            const entry = root.menuEntry
                            root.menuEntry = null
                            root.togglePinned(entry)
                        }
                    }

                    MenuButton {
                        visible: !menuOverlay.pickingCategory
                        Layout.fillWidth: true
                        buttonText: AppSearch.isHidden(root.menuEntry)
                            ? qsTr("Unhide app") : qsTr("Hide app")
                        onClicked: {
                            const entry = root.menuEntry
                            root.menuEntry = null
                            root.toggleHidden(entry)
                        }
                    }

                    MenuButton {
                        visible: !menuOverlay.pickingCategory
                        Layout.fillWidth: true
                        buttonText: qsTr("Move to category...")
                        onClicked: menuOverlay.pickingCategory = true
                    }

                    // Extra actions from the desktop entry (e.g. "New private window")
                    Rectangle {
                        visible: !menuOverlay.pickingCategory
                            && (root.menuEntry?.actions ?? []).length > 0
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Appearance.colors.colOutlineVariant
                    }
                    Repeater {
                        model: menuOverlay.pickingCategory ? [] : (root.menuEntry?.actions ?? [])

                        delegate: MenuButton {
                            required property var modelData
                            Layout.fillWidth: true
                            buttonText: modelData.name
                            onClicked: {
                                const action = modelData
                                root.menuEntry = null
                                action.execute()
                            }
                        }
                    }

                    // Category picker
                    MenuButton {
                        visible: menuOverlay.pickingCategory
                        Layout.fillWidth: true
                        buttonText: StringUtils.format(qsTr("Auto ({0})"),
                            root.menuEntry ? AppSearch.autoCategoryOf(root.menuEntry) : "")
                        onClicked: {
                            const entry = root.menuEntry
                            root.menuEntry = null
                            root.setCategoryOverride(entry, null)
                        }
                    }
                    Repeater {
                        model: menuOverlay.pickingCategory ? AppSearch.categoryOrder : []

                        delegate: MenuButton {
                            required property var modelData
                            Layout.fillWidth: true
                            buttonText: (root.menuEntry && AppSearch.categoryOf(root.menuEntry) === modelData
                                ? "✓ " : "  ") + modelData
                            onClicked: {
                                const entry = root.menuEntry
                                const category = modelData
                                root.menuEntry = null
                                root.setCategoryOverride(entry, category)
                            }
                        }
                    }
                }
            }
        }
    }
}
