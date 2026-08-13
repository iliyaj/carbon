// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Carbon contributors

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: filterPlayers(Mpris.players.values)
    property MprisPlayer activePlayer: null

    // Most-recent-first history gives paused players a stable fallback order.
    property var _activityHistory: []

    function isPlayerctld(player: MprisPlayer): bool {
        return player.dbusName.startsWith("org.mpris.MediaPlayer2.playerctld")
    }

    function isNativeBrowser(player: MprisPlayer): bool {
        const name = player.dbusName
        return name.startsWith("org.mpris.MediaPlayer2.firefox")
            || name.startsWith("org.mpris.MediaPlayer2.chromium")
            || name.startsWith("org.mpris.MediaPlayer2.google_chrome")
    }

    function isPlasmaBrowserIntegration(player: MprisPlayer): bool {
        return player.dbusName.startsWith("org.mpris.MediaPlayer2.plasma-browser-integration")
    }

    function filterPlayers(discoveredPlayers): var {
        const directPlayers = discoveredPlayers.filter(player => !isPlayerctld(player))
        const hasNativeBrowser = directPlayers.some(player => isNativeBrowser(player))

        // Plasma Browser Integration is valuable for browsers without native MPRIS,
        // but represents the same browser twice when a native service is present.
        return directPlayers.filter(player =>
            !hasNativeBrowser || !isPlasmaBrowserIntegration(player)
        )
    }

    function containsPlayer(player: MprisPlayer): bool {
        if (player === null)
            return false

        for (const candidate of players) {
            if (candidate === player)
                return true
        }
        return false
    }

    function rememberPlayer(player: MprisPlayer): void {
        if (!containsPlayer(player))
            return

        const updatedHistory = [player]
        for (const candidate of _activityHistory) {
            if (candidate !== null && candidate !== player && containsPlayer(candidate))
                updatedHistory.push(candidate)
        }
        _activityHistory = updatedHistory
    }

    function mostRecentPlayer(playingOnly: bool): MprisPlayer {
        for (const candidate of _activityHistory) {
            if (containsPlayer(candidate) && (!playingOnly || candidate.isPlaying))
                return candidate
        }

        for (const candidate of players) {
            if (!playingOnly || candidate.isPlaying)
                return candidate
        }
        return null
    }

    function reconcilePlayers(): void {
        const currentIsAvailable = containsPlayer(activePlayer)

        if (currentIsAvailable && activePlayer.isPlaying) {
            rememberPlayer(activePlayer)
            return
        }

        activePlayer = mostRecentPlayer(true) ?? mostRecentPlayer(false)
        if (activePlayer !== null)
            rememberPlayer(activePlayer)
    }

    function playerBecameActive(player: MprisPlayer): void {
        if (!containsPlayer(player)) {
            reconcilePlayers()
            return
        }

        rememberPlayer(player)
        activePlayer = player
    }

    function playerChangedTrack(player: MprisPlayer): void {
        if (!containsPlayer(player)) {
            reconcilePlayers()
            return
        }

        rememberPlayer(player)
        if (player.isPlaying || !containsPlayer(activePlayer) || !activePlayer.isPlaying)
            activePlayer = player
    }

    onPlayersChanged: Qt.callLater(reconcilePlayers)

    Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData

            function onPlaybackStateChanged(): void {
                if (modelData.isPlaying)
                    root.playerBecameActive(modelData)
                else
                    root.reconcilePlayers()
            }

            function onTrackChanged(): void {
                // Quickshell intentionally requires consumers to request position
                // notifications while displaying a changing progress value.
                modelData.positionChanged()
                root.playerChangedTrack(modelData)
            }

            Component.onCompleted: Qt.callLater(root.reconcilePlayers)
        }
    }

    IpcHandler {
        target: "mpris"

        function next(): void {
            if (root.activePlayer?.canGoNext)
                root.activePlayer.next()
        }

        function previous(): void {
            if (root.activePlayer?.canGoPrevious)
                root.activePlayer.previous()
        }

        function pauseAll(): void {
            for (const player of root.players) {
                if (player.isPlaying && player.canPause)
                    player.pause()
            }
        }

        function playPause(): void {
            if (root.activePlayer?.canTogglePlaying)
                root.activePlayer.togglePlaying()
        }
    }
}
