pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Singleton {
    property QtObject appearance: QtObject {
        property int fakeScreenRounding: 2 // 0: None | 1: Always | 2: When not fullscreen
        property bool transparency: false
        property bool themedResourceColors: false
        property QtObject palette: QtObject {
            property string type: "auto" // Allowed: auto, scheme-content, scheme-expressive, scheme-fidelity, scheme-fruit-salad, scheme-monochrome, scheme-neutral, scheme-rainbow, scheme-tonal-spot
        }
    }

    property QtObject audio: QtObject {
        // Values in %
        property QtObject protection: QtObject {
            // Prevent sudden bangs
            property bool enable: true
            property real maxAllowedIncrease: 10
            property real maxAllowed: 90 // Realistically should already provide some protection when it's 99...
        }
    }

    property QtObject apps: QtObject {
        property string bluetooth: "kcmshell6 kcm_bluetooth"
        property string network: "plasmawindowed org.kde.plasma.networkmanagement"
        property string networkEthernet: "kcmshell6 kcm_networkmanagement"
        property string taskManager: "missioncenter"
        property string terminal: "kitty -1" // This is only for shell actions
    }

    property QtObject background: QtObject {
        property bool showClock: true
        property bool fixedClockPosition: false
        property real clockX: -500
        property real clockY: -500
    }

    property QtObject autolock: QtObject {
        property int timeout: 300 // seconds (5 minutes default)
    }

    property QtObject bar: QtObject {
        property bool bottom: false // Instead of top
        property bool borderless: false // true for no grouping of items
        property bool showBackground: true
        property bool verbose: true
        property list<string> screenList: [] // List of names, like "eDP-1", find out with 'hyprctl monitors' command
        property QtObject utilButtons: QtObject {
            property bool showScreenSnip: true
            property bool showScreenSnipDelayed: true
            property bool showColorPicker: false
            property bool showClipboard: true
            property bool showMicToggle: false
            property bool showKeyboardToggle: true
            property bool showDarkModeToggle: true
        }
        property QtObject tray: QtObject {
            property bool monochromeIcons: true
        }
        property QtObject workspaces: QtObject {
            property int shown: 10
            property bool showAppIcons: true
            property bool alwaysShowNumbers: false
            property int showNumberDelay: 300 // milliseconds
        }
    }

    property QtObject battery: QtObject {
        property int low: 20
        property int critical: 5
        property bool automaticSuspend: true
        property int suspend: 3
    }

    property QtObject dock: QtObject {
        property real height: 60
        property real hoverRegionHeight: 3
        property bool pinnedOnStartup: false
        property bool hoverToReveal: false // When false, only reveals on empty workspace
        property list<string> pinnedApps: [ // IDs of pinned entries
            "org.kde.dolphin", "kitty",]
    }

    property QtObject appDrawer: QtObject {
        property list<string> pinnedApps: [] // IDs of apps pinned to the top of the app drawer
        property list<string> hiddenApps: [] // IDs of apps hidden from the app drawer
        property var categoryOverrides: ({ // Desktop entry id -> category, for apps whose Categories= put them somewhere unhelpful
            "monero-gui": "Productivity & Finance",
            "com.github.johnfactotum.foliate": "Information & Reading"
        })
    }

    property QtObject language: QtObject {
        property QtObject translator: QtObject {
            property string engine: "auto" // Run `trans -list-engines` for available engines. auto should use google
            property string targetLanguage: "auto" // Run `trans -list-all` for available languages
            property string sourceLanguage: "auto"
        }
    }

    property QtObject networking: QtObject {
        property string userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
    }

    property QtObject nightLight: QtObject {
        property bool manualSchedule: false // fixed clock times instead of solar elevation
        property int dayTemperature: 6500
        property int nightTemperature: 3800
        property string sunriseTime: "06:30" // start of the morning fade
        property string sunsetTime: "20:00" // start of the evening fade
        property int transitionMinutes: 60
        property bool systemLocation: true // take coordinates from the system timezone
        property real latitude: -37.82
        property real longitude: 144.97
    }

    property QtObject notifications: QtObject {
        property int maxRetained: 200
        property int persistDebounce: 500
        property int timeout: 5000
    }

    property QtObject osd: QtObject {
        property int timeout: 1000
    }

    property QtObject osk: QtObject {
        property string layout: "qwerty_full"
        property bool pinnedOnStartup: false
    }

    property QtObject overview: QtObject {
        property real scale: 0.18 // Relative to screen size
        property real rows: 2
        property real columns: 5
    }

    property QtObject resources: QtObject {
        property int updateInterval: 3000
    }

    property QtObject search: QtObject {
        property int nonAppResultDelay: 30 // This prevents lagging when typing
        property string engineBaseUrl: "https://www.google.com/search?q="
        property list<string> excludedSites: ["quora.com"]
        property bool sloppy: false // Uses levenshtein distance based scoring instead of fuzzy sort. Very weird.
        property QtObject prefix: QtObject {
            property string action: "/"
            property string clipboard: ";"
        }
    }

    property QtObject sidebar: QtObject {
        property QtObject translator: QtObject {
            property int delay: 300 // Delay before sending request. Reduces (potential) rate limits and lag.
        }
    }

    property QtObject time: QtObject {
        // https://doc.qt.io/qt-6/qtime.html#toString
        property string format: "hh:mm"
        property string dateFormat: "dddd, dd/MM"
    }

    property QtObject windows: QtObject {
        property bool showTitlebar: true // Client-side decoration for shell apps
        property bool centerTitle: true
        property bool showWindowControls: false
    }

    property QtObject hacks: QtObject {
        property int arbitraryRaceConditionDelay: 20 // milliseconds
    }
}
