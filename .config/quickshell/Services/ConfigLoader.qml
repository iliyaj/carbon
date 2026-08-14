pragma Singleton
pragma ComponentBehavior: Bound

import "root:/Modules/Common"
import "root:/Modules/Common/Functions/file_utils.js" as FileUtils
import "root:/Modules/Common/Functions/object_utils.js" as ObjectUtils
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Loads and manages the shell configuration file.
 * The config file is by default at XDG_CONFIG_HOME/carbon/config.json.
 * Automatically reloaded when the file changes.
 */
Singleton {
    id: root
    property string filePath: Directories.shellConfigPath
    property string legacyFilePath: FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`)
    property bool firstLoad: true
    property bool migrationRequested: false
    property bool preventNextLoad: false
    property var preventNextNotification: false

    function loadConfig() {
        configFileView.reload()
    }

    function applyConfig(fileContent) {
        try {
            if (fileContent.trim() === "")
                throw new Error("Config file is empty")
            const json = JSON.parse(fileContent);
            if (json === null || Array.isArray(json) || typeof json !== "object")
                throw new Error("Config root must be an object")

            ObjectUtils.applyToQtObject(ConfigOptions, json);
            if (root.firstLoad) {
                root.firstLoad = false;
                root.preventNextLoad = true;
                root.saveConfig(); // Make sure new properties are added to the user's config file
            }
        } catch (e) {
            console.error("[ConfigLoader] Error reading file:", e);
            Quickshell.execDetached(["notify-send", qsTr("Shell configuration failed to load"), root.filePath])
            return;
        }
    }

    function setLiveConfigValue(nestedKey, value) {
        let keys = nestedKey.split(".");
        let obj = ConfigOptions;
        let parents = [obj];

        // Traverse and collect parent objects
        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object") {
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
            parents.push(obj);
        }

        // Convert value to correct type using JSON.parse when safe
        let convertedValue = value;
        if (typeof value === "string") {
            let trimmed = value.trim();
            if (trimmed === "true" || trimmed === "false" || !isNaN(Number(trimmed))) {
                try {
                    convertedValue = JSON.parse(trimmed);
                } catch (e) {
                    convertedValue = value;
                }
            }
        }

        obj[keys[keys.length - 1]] = convertedValue;
    }

    function saveConfig() {
        const plainConfig = ObjectUtils.toPlainObject(ConfigOptions)
        const jsonContent = JSON.stringify(plainConfig, null, 2)
        configFileView.setText(jsonContent)
    }

    function migrateLegacyConfig(fileContent) {
        root.migrationRequested = false
        try {
            const json = JSON.parse(fileContent)
            if (json === null || Array.isArray(json) || typeof json !== "object")
                throw new Error("Config root must be an object")
            console.log("[ConfigLoader] Migrating legacy configuration to", root.filePath)
            configFileView.setText(fileContent)
        } catch (error) {
            console.error("[ConfigLoader] Legacy configuration is invalid:", error)
            Quickshell.execDetached(["notify-send", qsTr("Previous shell configuration could not be migrated"), root.legacyFilePath])
            root.saveConfig()
        }
    }

    function setConfigValueAndSave(nestedKey, value, preventNextNotification = true) {
        setLiveConfigValue(nestedKey, value);
        root.preventNextNotification = preventNextNotification;
        saveConfig();
    }

    Timer {
        id: delayedFileRead
        interval: ConfigOptions.hacks.arbitraryRaceConditionDelay
        running: false
        onTriggered: {
            if (root.preventNextLoad) {
                root.preventNextLoad = false;
                return;
            }
            if (root.firstLoad) {
                root.applyConfig(configFileView.text())
            } else {
                root.applyConfig(configFileView.text())
                if (!root.preventNextNotification) {
                    // Quickshell.execDetached(["bash", "-c", `notify-send '${qsTr("Shell configuration reloaded")}' '${root.filePath}'`])
                } else {
                    root.preventNextNotification = false;
                }
            }
        }
    }

	FileView {
        id: configFileView
        path: Qt.resolvedUrl(root.filePath)
        atomicWrites: true
        printErrors: false
        watchChanges: true
        onFileChanged: {
            this.reload()
            delayedFileRead.start()
        }
        onLoadedChanged: {
            const fileContent = configFileView.text()
            delayedFileRead.start()
        }
        onLoadFailed: (error) => {
            if(error == FileViewError.FileNotFound) {
                console.log("[ConfigLoader] File not found, checking for a previous configuration.")
                root.migrationRequested = true
            } else {
                Quickshell.execDetached(["notify-send", qsTr("Shell configuration failed to load"), root.filePath])
            }
        }
        onSaveFailed: (error) => {
            console.error("[ConfigLoader] Error saving file:", error)
            Quickshell.execDetached(["notify-send", qsTr("Shell configuration failed to save"), root.filePath])
        }
    }

    FileView {
        id: legacyConfigFileView
        path: Qt.resolvedUrl(root.legacyFilePath)
        preload: root.migrationRequested
        printErrors: false
        onLoaded: {
            if (root.migrationRequested)
                root.migrateLegacyConfig(legacyConfigFileView.text())
        }
        onLoadFailed: (error) => {
            if (!root.migrationRequested)
                return

            root.migrationRequested = false
            if (error != FileViewError.FileNotFound) {
                console.error("[ConfigLoader] Error reading previous configuration:", error)
                Quickshell.execDetached(["notify-send", qsTr("Previous shell configuration could not be migrated"), root.legacyFilePath])
            }
            root.saveConfig()
        }
    }
}
