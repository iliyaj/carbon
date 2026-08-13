import "root:/Modules/Common"
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
pragma Singleton
pragma ComponentBehavior: Bound

/**
 * A nice wrapper for default Pipewire audio sink and source.
 */
Singleton {
    id: root

    property bool ready: Pipewire.defaultAudioSink?.ready ?? false
    property PwNode sink: Pipewire.defaultAudioSink
    property PwNode source: Pipewire.defaultAudioSource

    signal sinkProtectionTriggered(string reason);

    PwObjectTracker {
        objects: [sink, source]
    }

    Connections { // Protection against sudden volume changes
        target: sink?.audio ?? null
        property bool lastReady: false
        property real lastVolume: 0
        function onVolumeChanged() {
            if (!ConfigOptions.audio.protection.enable) return;
            if (!sink || !sink.ready || !sink.audio) return;

            if (!lastReady) {
                lastVolume = sink.audio.volume;
                lastReady = true;
                return;
            }
            const newVolume = sink.audio.volume;
            const maxAllowedIncrease = ConfigOptions.audio.protection.maxAllowedIncrease / 100;
            const maxAllowed = ConfigOptions.audio.protection.maxAllowed / 100;

            if (newVolume - lastVolume > maxAllowedIncrease) {
                if (sink.ready) {
                    sink.audio.volume = lastVolume;
                    root.sinkProtectionTriggered("Illegal increment");
                }
            } else if (newVolume > maxAllowed) {
                root.sinkProtectionTriggered("Exceeded max allowed");
                // Clamp to the limit rather than reverting, so the limit itself is reachable
                if (sink.ready) {
                    sink.audio.volume = maxAllowed;
                }
            }
            if (sink.ready && (isNaN(sink.audio.volume) || sink.audio.volume === undefined || sink.audio.volume === null)) {
                sink.audio.volume = 0;
            }
            lastVolume = sink.audio.volume;
        }

    }

}
