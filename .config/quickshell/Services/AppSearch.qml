pragma Singleton

import "root:/Modules/Common"
import "root:/Modules/Common/Functions/fuzzysort.js" as Fuzzy
import "root:/Modules/Common/Functions/levendist.js" as Levendist
import Quickshell
import Quickshell.Io

/**
 * - Eases fuzzy searching for applications by name
 * - Guesses icon name for window class name
 */
Singleton {
    id: root
    property bool sloppySearch: ConfigOptions?.search.sloppy ?? false
    property real scoreThreshold: 0.2
    property var substitutions: ({
        "gnome-tweaks": "org.gnome.tweaks",
        "pavucontrol-qt": "pavucontrol",
        "wps": "wps-office2019-kprometheus",
        "wpsoffice": "wps-office2019-kprometheus",
        "footclient": "foot",
        "zen": "zen-browser",
        "brave-browser": "brave-desktop",
        "proton.vpn.app.gtk": "proton-vpn-logo",
        "monero-core": "monero-custom",
        "code": "visual-studio-code",
        "Spotify": "spotify",
        "Logseq": "logseq",
        "btop": "btop"
    })
    property var regexSubstitutions: [
        {
            "regex": /^steam_app_(\\d+)$/,
            "replace": "steam_icon_$1"
        },
        {
            "regex": /Minecraft.*/,
            "replace": "minecraft"
        },
        {
            "regex": /.*polkit.*/,
            "replace": "system-lock-screen"
        },
        {
            "regex": /gcr.prompter/,
            "replace": "system-lock-screen"
        }
    ]

    // Apple App Library style grouping: maps freedesktop Categories= entries
    // to iOS-like groups. Rules are checked in order, first match wins, so
    // specific categories come before broad ones (e.g. TerminalEmulator before System).
    readonly property var categoryMatchRules: [
        { group: "Social", keys: ["InstantMessaging", "Chat", "IRCClient", "VideoConference", "Telephony", "ContactManagement", "Feed"] },
        { group: "Games", keys: ["Game"] },
        { group: "Creativity", keys: ["Graphics", "2DGraphics", "3DGraphics", "VectorGraphics", "RasterGraphics", "Photography", "Design", "AudioVideoEditing", "Recorder", "Publishing", "Scanning"] },
        { group: "Development", keys: ["Development", "IDE", "Debugger", "Building", "WebDevelopment", "RevisionControl"] },
        { group: "Utilities", keys: ["Settings", "HardwareSettings", "DesktopSettings", "Security", "Accessibility", "PackageManager", "TerminalEmulator", "FileManager", "FileTools", "Filesystem", "Monitor", "Archiving", "Compression", "DiscBurning", "Emulator"] },
        { group: "Productivity & Finance", keys: ["Office", "WordProcessor", "Spreadsheet", "Presentation", "Calendar", "ProjectManagement", "Finance", "Database", "Email", "TextEditor"] },
        { group: "Information & Reading", keys: ["WebBrowser", "News", "Dictionary", "Maps", "Education", "Science", "Documentation", "Viewer"] },
        { group: "Entertainment", keys: ["Player", "Music", "TV", "AudioVideo", "Audio", "Video"] },
        { group: "Utilities", keys: ["Utility", "System", "Network", "ConsoleOnly"] }
    ]

    readonly property var categoryIcons: ({
        "Pinned": "keep",
        "Social": "forum",
        "Creativity": "palette",
        "Productivity & Finance": "work",
        "Development": "code",
        "Information & Reading": "menu_book",
        "Entertainment": "movie",
        "Games": "sports_esports",
        "Utilities": "build",
        "Other": "apps",
        "Hidden": "visibility_off"
    })

    readonly property var categoryOrder: ["Social", "Creativity", "Productivity & Finance", "Development", "Information & Reading", "Entertainment", "Games", "Utilities", "Other"]

    // Desktop entry id normalized for use as key in config lists/overrides
    function entryId(entry): string {
        return (entry?.id ?? "").toLowerCase().replace(/\.desktop$/, "");
    }

    // Category from Categories= rules only, ignoring user overrides
    function autoCategoryOf(entry): string {
        const cats = entry.categories ?? [];
        for (const rule of categoryMatchRules) {
            for (const key of rule.keys) {
                if (cats.indexOf(key) !== -1) return rule.group;
            }
        }
        return "Other";
    }

    function categoryOf(entry): string {
        const overrides = ConfigOptions?.appDrawer.categoryOverrides ?? {};
        return overrides[entryId(entry)] ?? autoCategoryOf(entry);
    }

    // Hidden apps (appDrawer.hiddenApps in config); revealHidden temporarily
    // shows them in a "Hidden" section so they can be unhidden
    property bool revealHidden: false
    readonly property var hiddenIds: (ConfigOptions?.appDrawer.hiddenApps ?? []).map(id => id.toLowerCase())
    readonly property int hiddenCount: Array.from(DesktopEntries.applications.values)
        .filter(a => root.isHidden(a)).length

    function isHidden(entry): bool {
        return hiddenIds.indexOf(entryId(entry)) !== -1;
    }

    // Apps pinned to the top of the drawer (appDrawer.pinnedApps in config),
    // in the order they were pinned
    readonly property var pinnedIds: (ConfigOptions?.appDrawer.pinnedApps ?? []).map(id => id.toLowerCase())

    function isPinnedToTop(entry): bool {
        return pinnedIds.indexOf(entryId(entry)) !== -1;
    }

    // Ordered list of { name, icon, apps } for the categorized app drawer
    readonly property var groupedList: {
        const pinnedApps = root.pinnedIds
            .map(id => root.list.find(a => entryId(a) === id))
            .filter(a => a !== undefined);
        const pinnedSet = {};
        for (const app of pinnedApps) pinnedSet[entryId(app)] = true;

        const groups = {};
        for (const app of root.list) {
            if (pinnedSet[entryId(app)]) continue;
            const cat = root.isHidden(app) ? "Hidden" : categoryOf(app);
            if (!groups[cat]) groups[cat] = [];
            groups[cat].push(app);
        }

        const sections = [];
        if (pinnedApps.length > 0) sections.push({ name: "Pinned", icon: categoryIcons["Pinned"], apps: pinnedApps });
        for (const cat of categoryOrder.concat("Hidden")) {
            if (groups[cat] !== undefined) sections.push({ name: cat, icon: categoryIcons[cat], apps: groups[cat] });
        }
        return sections;
    }

    readonly property list<DesktopEntry> list: Array.from(DesktopEntries.applications.values)
        .filter(a => root.revealHidden || !root.isHidden(a))
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property var preppedNames: list.map(a => ({
                name: Fuzzy.prepare(`${a.name} `),
                entry: a
            }))

    function fuzzyQuery(search: string): var { // Idk why list<DesktopEntry> doesn't work
        if (root.sloppySearch) {
            const results = list.map(obj => ({
                entry: obj,
                score: Levendist.computeScore(obj.name.toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
                .sort((a, b) => b.score - a.score)
            return results
                .map(item => item.entry)
        }

        return Fuzzy.go(search, preppedNames, {
            all: true,
            key: "name"
        }).map(r => {
            return r.obj.entry
        });
    }

    function iconExists(iconName) {
        return (Quickshell.iconPath(iconName, true).length > 0)
            && !iconName.includes("image-missing");
    }

    function guessIcon(str) {
        if (!str || str.length == 0) return "image-missing";

        // Normal substitutions
        if (substitutions[str])
            return substitutions[str];

        // Regex substitutions
        for (let i = 0; i < regexSubstitutions.length; i++) {
            const substitution = regexSubstitutions[i];
            const replacedName = str.replace(
                substitution.regex,
                substitution.replace,
            );
            if (replacedName != str) return replacedName;
        }

        // If it gets detected normally, no need to guess
        if (iconExists(str)) return str;

        let guessStr = str;
        // Guess: Take only app name of reverse domain name notation
        guessStr = str.split('.').slice(-1)[0].toLowerCase();
        if (iconExists(guessStr)) return guessStr;
        // Guess: normalize to kebab case
        guessStr = str.toLowerCase().replace(/\s+/g, "-");
        if (iconExists(guessStr)) return guessStr;
        // Guess: First fuzze desktop entry match
        const searchResults = root.fuzzyQuery(str);
        if (searchResults.length > 0) {
            const firstEntry = searchResults[0];
            guessStr = firstEntry.icon
            if (iconExists(guessStr)) return guessStr;
        }

        // Give up
        return str;
    }
}
