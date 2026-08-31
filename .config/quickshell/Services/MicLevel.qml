pragma Singleton
pragma ComponentBehavior: Bound

import "root:/Modules/Common"
import "root:/Modules/Common/Functions"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    property int subscribers: 0
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool muted: source?.audio?.muted ?? true
    readonly property bool active: subscribers > 0 && !muted && sourceName.length > 0
    readonly property string sourceName: source?.name ?? "" // follows what the button mutes
    property real level: 0

    function subscribe(): void {
        subscribers += 1
    }

    function unsubscribe(): void {
        subscribers = Math.max(0, subscribers - 1)
    }

    function refresh(): void {
        levelProcess.running = false
        if (!active) {
            level = 0
            return
        }
        levelProcess.command = [`${Directories.scriptPath}/Audio/mic_level.py`, sourceName]
        levelProcess.running = true
    }

    onActiveChanged: refresh()
    onSourceNameChanged: refresh() // Process does not restart on a command change

    PwObjectTracker {
        objects: [root.source]
    }

    Process {
        id: levelProcess
        stdout: SplitParser {
            onRead: line => {
                const value = parseFloat(line)
                if (!isNaN(value))
                    root.level = Math.max(0, Math.min(1, value))
            }
        }
        stderr: SplitParser {
            onRead: line => console.log(`[MicLevel] ${line}`)
        }
    }
}
