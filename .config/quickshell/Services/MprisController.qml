// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Carbon contributors

pragma Singleton
pragma ComponentBehavior: Bound

import "root:/Modules/Common"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var _validPlayers: filterPlayers(Mpris.players.values)
    readonly property var players: deduplicatePlayers(_validPlayers)
    property MprisPlayer activePlayer: null

    // Most-recent-first history gives paused players a stable fallback order.
    property var _activityHistory: []
    property var _ownerPids: ({})
    property var _cachedArtUrls: ({})

    signal coverArtReady(artUrl: string)

    function coverArtFilePath(artUrl: string): string {
        return `${Directories.coverArt}/${Qt.md5(artUrl)}.jpg`
    }

    function isCoverArtReady(artUrl: string): bool {
        return artUrl.length > 0 && _cachedArtUrls[artUrl] === true
    }

    function rememberCoverArt(artUrl: string): void {
        if (artUrl.length === 0 || isCoverArtReady(artUrl))
            return

        const updatedCachedArtUrls = Object.assign({}, _cachedArtUrls)
        updatedCachedArtUrls[artUrl] = true
        _cachedArtUrls = updatedCachedArtUrls
        coverArtReady(artUrl)
    }

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

    function hasTrackData(player: MprisPlayer): bool {
        return String(player.trackTitle ?? "").trim().length > 0
            || String(player.trackArtist ?? "").trim().length > 0
            || String(player.trackAlbum ?? "").trim().length > 0
            || player.length > 0
    }

    function normalizedMetadata(value): string {
        return String(value ?? "").trim().toLowerCase().replace(/\s+/g, " ")
    }

    function titleIncludesTrackAndArtist(trackPlayer: MprisPlayer, combinedPlayer: MprisPlayer): bool {
        const title = normalizedMetadata(trackPlayer.trackTitle)
        const artist = normalizedMetadata(trackPlayer.trackArtist)
        const combinedTitle = normalizedMetadata(combinedPlayer.trackTitle)
        return title.length > 0
            && artist.length > 0
            && combinedTitle !== title
            && combinedTitle.startsWith(title)
            && combinedTitle.endsWith(artist)
    }

    function areDuplicatePlayers(first: MprisPlayer, second: MprisPlayer): bool {
        if (!first || !second)
            return false

        const firstOwnerPid = _ownerPids[first.dbusName] ?? 0
        const secondOwnerPid = _ownerPids[second.dbusName] ?? 0
        // One app can expose native and Chromium services whose titles diverge while paused.
        if (firstOwnerPid > 0 && firstOwnerPid === secondOwnerPid)
            return true

        const firstTitle = normalizedMetadata(first.trackTitle)
        const secondTitle = normalizedMetadata(second.trackTitle)
        if (firstTitle.length === 0 || secondTitle.length === 0)
            return false

        const firstArtist = normalizedMetadata(first.trackArtist)
        const secondArtist = normalizedMetadata(second.trackArtist)
        if (firstArtist.length > 0 && secondArtist.length > 0 && firstArtist !== secondArtist)
            return false

        const shorterTitle = firstTitle.length <= secondTitle.length ? firstTitle : secondTitle
        const longerTitle = firstTitle.length > secondTitle.length ? firstTitle : secondTitle
        const titlesMatch = firstTitle === secondTitle
            || (shorterTitle.length >= 8 && longerTitle.includes(shorterTitle))
            || titleIncludesTrackAndArtist(first, second)
            || titleIncludesTrackAndArtist(second, first)
        if (!titlesMatch)
            return false

        // The same title can identify different recordings.
        return first.length <= 0
            || second.length <= 0
            || Math.abs(first.length - second.length) <= 2
    }

    function playerQuality(player: MprisPlayer): int {
        // Native endpoints carry richer metadata than their browser mirrors.
        return (player.isPlaying ? 16 : 0)
            + (String(player.trackArtUrl ?? "").length > 0 ? 8 : 0)
            + (normalizedMetadata(player.trackArtist).length > 0 ? 4 : 0)
            + (normalizedMetadata(player.trackAlbum).length > 0 ? 2 : 0)
            + (player.length > 0 ? 1 : 0)
    }

    function deduplicatePlayers(validPlayers): var {
        const canonicalPlayers = []

        for (const player of validPlayers) {
            if (!player)
                continue

            const duplicateIndex = canonicalPlayers.findIndex(candidate => areDuplicatePlayers(candidate, player))
            if (duplicateIndex === -1) {
                canonicalPlayers.push(player)
            } else if (playerQuality(player) > playerQuality(canonicalPlayers[duplicateIndex])) {
                canonicalPlayers[duplicateIndex] = player
            }
        }

        return canonicalPlayers
    }

    function rememberOwnerPid(dbusName: string, ownerPid: int): void {
        if (ownerPid <= 0 || _ownerPids[dbusName] === ownerPid)
            return

        const updatedOwnerPids = Object.assign({}, _ownerPids)
        updatedOwnerPids[dbusName] = ownerPid
        _ownerPids = updatedOwnerPids
    }

    function forgetOwnerPid(dbusName: string): void {
        if (_ownerPids[dbusName] === undefined)
            return

        const updatedOwnerPids = Object.assign({}, _ownerPids)
        delete updatedOwnerPids[dbusName]
        _ownerPids = updatedOwnerPids
    }

    function trackLengthFor(player: MprisPlayer): real {
        if (!player)
            return 0

        let trackLength = player.length ?? 0
        for (const candidate of _validPlayers) {
            if (candidate && candidate.length > trackLength && areDuplicatePlayers(player, candidate))
                trackLength = candidate.length
        }
        return trackLength
    }

    function filterPlayers(discoveredPlayers): var {
        // Quickshell can briefly leave a null entry while an MPRIS service disappears.
        const directPlayers = discoveredPlayers.filter(player => player !== null
            && player !== undefined
            && !isPlayerctld(player))
        const hasNativeBrowser = directPlayers.some(player => isNativeBrowser(player))

        // Plasma Browser Integration is valuable for browsers without native MPRIS,
        // but represents the same browser twice when a native service is present.
        return directPlayers.filter(player => {
            if (hasNativeBrowser && isPlasmaBrowserIntegration(player))
                return false

            // Chromium can retain only a temporary artwork URL after media closes.
            return player.playbackState !== MprisPlaybackState.Stopped
                || player.canPlay
                || hasTrackData(player)
        })
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

        delegate: Scope {
            required property MprisPlayer modelData
            property string playerDbusName: ""
            property string playerArtUrl: root.hasTrackData(modelData)
                ? String(modelData.trackArtUrl ?? "")
                : ""

            function downloadCurrentArt(): void {
                if (coverArtDownloader.running) {
                    // Skipped tracks must not hold up the current cover.
                    if (coverArtDownloader.targetFile !== playerArtUrl)
                        coverArtDownloader.running = false
                    return
                }

                if (playerArtUrl.length === 0 || root.isCoverArtReady(playerArtUrl))
                    return

                coverArtDownloader.targetFile = playerArtUrl
                coverArtDownloader.outputFile = root.coverArtFilePath(playerArtUrl)
                coverArtDownloader.running = true
            }

            onPlayerArtUrlChanged: downloadCurrentArt()

            Connections {
                target: modelData

                function onPlaybackStateChanged(): void {
                    if (modelData?.isPlaying)
                        root.playerBecameActive(modelData)
                    else
                        root.reconcilePlayers()
                }

                function onTrackChanged(): void {
                    // Quickshell intentionally requires consumers to request position
                    // notifications while displaying a changing progress value.
                    modelData?.positionChanged()
                    root.playerChangedTrack(modelData)
                }
            }

            Process {
                id: ownerPidLookup
                command: [
                    "busctl", "--user", "call",
                    "org.freedesktop.DBus", "/org/freedesktop/DBus",
                    "org.freedesktop.DBus", "GetConnectionUnixProcessID",
                    "s", playerDbusName
                ]

                stdout: StdioCollector {
                    onStreamFinished: {
                        const match = text.match(/^u\s+(\d+)/)
                        if (match)
                            root.rememberOwnerPid(playerDbusName, Number(match[1]))
                    }
                }
            }

            Process {
                id: coverArtDownloader
                property string targetFile: ""
                property string outputFile: ""
                command: [
                    "bash", "-c",
                    `[ -s "$1" ] || exec curl -4 --fail --silent --show-error --location --remove-on-error "$2" --output "$1"`,
                    "cover-art", outputFile, targetFile
                ]
                onExited: exitCode => {
                    const completedArtUrl = targetFile
                    if (exitCode === 0) {
                        root.rememberCoverArt(completedArtUrl)
                    } else if (completedArtUrl === playerArtUrl) {
                        console.warn(`[MprisController] Failed to download cover art: ${completedArtUrl}`)
                    }

                    if (completedArtUrl !== playerArtUrl && playerArtUrl.length > 0)
                        Qt.callLater(downloadCurrentArt)
                }
            }

            Component.onCompleted: {
                playerDbusName = modelData.dbusName
                ownerPidLookup.running = true
                downloadCurrentArt()
                Qt.callLater(root.reconcilePlayers)
            }
            Component.onDestruction: root.forgetOwnerPid(playerDbusName)
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
            for (const player of root._validPlayers) {
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
