// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Carbon contributors

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var outputs: []
    property bool available: false
    property bool loading: false
    property bool previewActive: false
    property string transactionId: ""
    property int remainingMilliseconds: 0
    property int remainingSeconds: 0
    property string errorMessage: ""
    property string statusMessage: ""

    function refresh() {
        if (outputsProcess.running)
            return
        root.loading = true
        root.errorMessage = ""
        outputsProcess.running = true
    }

    function preview(output: string, modeId: string) {
        if (previewProcess.running || root.previewActive)
            return
        root.errorMessage = ""
        root.statusMessage = "Nagame is validating the complete display configuration…"
        previewProcess.command = ["nagame", "display", "preview", "--output", output, "--mode", modeId]
        previewProcess.running = true
    }

    function revert() {
        if (!root.previewActive || revertProcess.running)
            return
        root.statusMessage = "Restoring the previous display configuration…"
        revertProcess.command = ["nagame", "display", "revert", "--transaction", root.transactionId]
        revertProcess.running = true
    }

    function handleEvent(line: string) {
        if (line.trim().length === 0)
            return

        let event
        try {
            event = JSON.parse(line)
        } catch (error) {
            root.errorMessage = qsTr("Nagame returned an invalid response: %1").arg(error)
            return
        }

        switch (event.event) {
        case "outputs":
            root.outputs = event.outputs ?? []
            root.available = true
            root.loading = false
            break
        case "preview_started":
            root.previewActive = true
            root.transactionId = event.transaction_id
            root.remainingMilliseconds = Math.max(0, Number(event.remaining_ms ?? 0))
            root.updateCountdown()
            root.statusMessage = qsTr("Preview active. It will revert automatically in %1 seconds.").arg(root.remainingSeconds)
            break
        case "preview_reverted":
            root.previewActive = false
            root.transactionId = ""
            root.remainingMilliseconds = 0
            root.remainingSeconds = 0
            root.statusMessage = event.reason === "manual"
                ? qsTr("Previous display mode restored.")
                : qsTr("Preview ended and the previous display mode was restored.")
            root.refresh()
            break
        case "revert_completed":
            root.previewActive = false
            root.transactionId = ""
            root.remainingMilliseconds = 0
            root.remainingSeconds = 0
            root.statusMessage = qsTr("Previous display mode restored.")
            root.refresh()
            break
        case "error":
            root.errorMessage = event.message ?? qsTr("Nagame could not complete the request.")
            root.loading = false
            break
        }
    }

    function updateCountdown() {
        root.remainingSeconds = Math.ceil(root.remainingMilliseconds / 1000)
        if (root.previewActive)
            root.statusMessage = qsTr("Preview active. It will revert automatically in %1 seconds.").arg(root.remainingSeconds)
    }

    Timer {
        interval: 200
        repeat: true
        running: root.previewActive
        onTriggered: {
            root.remainingMilliseconds = Math.max(0, root.remainingMilliseconds - interval)
            root.updateCountdown()
        }
    }

    Process {
        id: outputsProcess
        command: ["nagame", "display", "outputs"]
        stdout: SplitParser {
            onRead: data => root.handleEvent(data)
        }
        onExited: (exitCode, exitStatus) => {
            root.loading = false
            if (exitCode !== 0 && root.outputs.length === 0) {
                root.available = false
                if (root.errorMessage.length === 0)
                    root.errorMessage = qsTr("Nagame is not available. Carbon's display fallback remains active.")
            }
        }
    }

    Process {
        id: previewProcess
        stdout: SplitParser {
            onRead: data => root.handleEvent(data)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.errorMessage.length === 0)
                root.errorMessage = qsTr("The display preview command ended unexpectedly.")
        }
    }

    Process {
        id: revertProcess
        stdout: SplitParser {
            onRead: data => root.handleEvent(data)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.errorMessage.length === 0)
                root.errorMessage = qsTr("Nagame could not restore the previous display mode.")
        }
    }
}
