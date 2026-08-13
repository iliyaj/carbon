import QtQuick
import Quickshell
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    property QtObject sidebar: QtObject {
        property QtObject bottomGroup: QtObject {
            property bool collapsed: false
        }
    }

    property QtObject idle: QtObject {
        property bool inhibit: false
    }

}
