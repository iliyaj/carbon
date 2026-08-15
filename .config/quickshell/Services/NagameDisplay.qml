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
    property string activeProfile: ""
    property string configRevision: ""
    property bool available: false
    property bool outputManagementSupported: false
    property bool loading: false
    property bool previewActive: false
    property bool confirming: false
    property bool reverting: false
    property string transactionId: ""
    property int remainingMilliseconds: 0
    property int remainingSeconds: 0
    property string errorCode: ""
    property string errorMessage: ""
    property string statusMessage: ""

    function refresh(clearError = true, showLoading = true) {
        if (outputsProcess.running)
            return
        if (showLoading)
            root.loading = true
        if (clearError) {
            root.errorCode = ""
            root.errorMessage = ""
        }
        outputsProcess.running = true
    }

    function preview(output: string, modeId: string) {
        if (previewProcess.running || root.previewActive)
            return
        root.errorCode = ""
        root.errorMessage = ""
        root.statusMessage = "Nagame is validating the complete display configuration…"
        previewProcess.command = [
            "nagame", "display", "preview",
            "--output", output,
            "--mode", modeId,
            "--profile", root.activeProfile,
            "--revision", root.configRevision
        ]
        previewProcess.running = true
    }

    function confirm() {
        if (!root.previewActive || confirmProcess.running || root.reverting)
            return
        root.confirming = true
        root.errorCode = ""
        root.errorMessage = ""
        root.statusMessage = qsTr("Saving the display mode to Nagame…")
        confirmProcess.command = ["nagame", "display", "confirm", "--transaction", root.transactionId]
        confirmProcess.running = true
    }

    function revert() {
        if (!root.previewActive || revertProcess.running || root.confirming)
            return
        root.reverting = true
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
            root.errorCode = "invalid_response"
            root.errorMessage = qsTr("Nagame returned an invalid response: %1").arg(error)
            return
        }

        switch (event.event) {
        case "outputs":
            if (!Array.isArray(event.outputs) || event.outputs.some(output => {
                return typeof output.connector !== "string"
                    || typeof output.name !== "string"
                    || typeof output.enabled !== "boolean"
                    || !Array.isArray(output.modes)
                    || output.modes.some(mode => {
                        return typeof mode.id !== "string"
                            || !Number.isFinite(mode.width)
                            || !Number.isFinite(mode.height)
                            || !Number.isFinite(mode.refresh_mhz)
                            || typeof mode.preferred !== "boolean"
                    })
            })) {
                root.outputs = []
                root.available = false
                root.loading = false
                root.errorCode = "invalid_data"
                root.errorMessage = qsTr("Nagame returned incomplete display data. Retry after checking the service logs.")
                break
            }
            if (JSON.stringify(root.outputs) !== JSON.stringify(event.outputs))
                root.outputs = event.outputs
            root.activeProfile = event.active_profile ?? ""
            root.configRevision = event.revision ?? ""
            root.outputManagementSupported = event.supported ?? false
            root.available = true
            root.loading = false
            if (root.errorCode === "daemon_unavailable" || root.errorCode === "invalid_response" || root.errorCode === "invalid_data") {
                root.errorCode = ""
                root.errorMessage = ""
            }
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
            root.confirming = false
            root.reverting = false
            root.transactionId = ""
            root.remainingMilliseconds = 0
            root.remainingSeconds = 0
            if (event.reason === "manual") {
                root.statusMessage = qsTr("Previous display mode restored.")
            } else if (event.reason === "configuration_changed") {
                root.statusMessage = qsTr("A newer display configuration was loaded and the preview was reverted.")
                root.errorCode = "config_conflict"
                root.errorMessage = qsTr("The display configuration changed elsewhere. The newer configuration won.")
            } else if (event.reason === "outputs_changed") {
                root.statusMessage = qsTr("Connected displays changed and the preview was cancelled.")
                root.errorCode = "outputs_changed"
                root.errorMessage = qsTr("The display arrangement changed. Review the connected displays before trying again.")
            } else {
                root.statusMessage = qsTr("Preview ended and the previous display mode was restored.")
            }
            root.refresh(false, false)
            break
        case "preview_confirmed":
        case "confirm_completed":
            root.previewActive = false
            root.confirming = false
            root.reverting = false
            root.transactionId = ""
            root.remainingMilliseconds = 0
            root.remainingSeconds = 0
            root.configRevision = event.revision ?? root.configRevision
            root.statusMessage = qsTr("Display changes saved.")
            root.refresh(false, false)
            break
        case "revert_completed":
            root.previewActive = false
            root.confirming = false
            root.reverting = false
            root.transactionId = ""
            root.remainingMilliseconds = 0
            root.remainingSeconds = 0
            root.statusMessage = qsTr("Previous display mode restored.")
            root.refresh(false, false)
            break
        case "error":
            root.errorCode = event.code ?? "request_failed"
            root.errorMessage = event.message ?? qsTr("Nagame could not complete the request.")
            root.confirming = false
            root.loading = false
            if (event.code === "config_conflict" || event.code === "profile_changed")
                root.refresh(false, false)
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

    Timer {
        interval: 2000
        repeat: true
        running: !root.previewActive
        triggeredOnStart: false
        onTriggered: root.refresh(false, false)
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
                if (root.errorMessage.length === 0) {
                    root.errorCode = "daemon_unavailable"
                    root.errorMessage = qsTr("Nagame is not available. Carbon's display fallback remains active.")
                }
            }
        }
    }

    Process {
        id: previewProcess
        stdout: SplitParser {
            onRead: data => root.handleEvent(data)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.errorMessage.length === 0) {
                root.errorCode = "preview_failed"
                root.errorMessage = qsTr("The display preview command ended unexpectedly.")
            }
        }
    }

    Process {
        id: confirmProcess
        stdout: SplitParser {
            onRead: data => root.handleEvent(data)
        }
        onExited: (exitCode, exitStatus) => {
            root.confirming = false
            if (exitCode !== 0 && root.errorMessage.length === 0) {
                root.errorCode = "confirm_failed"
                root.errorMessage = qsTr("Nagame could not save the display mode.")
            }
        }
    }

    Process {
        id: revertProcess
        stdout: SplitParser {
            onRead: data => root.handleEvent(data)
        }
        onExited: (exitCode, exitStatus) => {
            root.reverting = false
            if (exitCode !== 0 && root.errorMessage.length === 0) {
                root.errorCode = "revert_failed"
                root.errorMessage = qsTr("Nagame could not restore the previous display mode.")
            }
        }
    }
}
