import qs.Modules.Common
import qs.Modules.Common.Functions
import qs.Modules.ScreenCapture
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    readonly property bool recording: recorderProcess.running
    readonly property bool selectingRegion: regionChooser.active
    readonly property string recorderUnit: "carbon-screen-recorder.service"
    property bool stopRequested: false
    property var pendingCommand: []
    property string outputPath: ""

    Connections {
        target: Quickshell

        function onReloadCompleted(): void {
            root.stopRecording()
        }
    }

    function notify(title: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "Recorder", title, body])
    }

    function timestamp(): string {
        const now = new Date()
        const pad = value => String(value).padStart(2, "0")
        return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}_${pad(now.getHours())}.${pad(now.getMinutes())}.${pad(now.getSeconds())}`
    }

    function toggleRegion(): void {
        if (stopOrCancel())
            return
        regionChooser.active = true
    }

    function toggleFullscreen(withAudio: bool): void {
        if (stopOrCancel())
            return

        const monitor = Hyprland.focusedMonitor?.name ?? ""
        if (monitor.length === 0) {
            notify("Recording cancelled", "Could not determine the active monitor")
            return
        }
        prepareRecording(["-o", monitor], withAudio)
    }

    function startRegion(geometry: string, withAudio: bool): void {
        if (stopOrCancel())
            return
        if (geometry.trim().length === 0) {
            notify("Recording cancelled", "No region was provided")
            return
        }
        prepareRecording(["--geometry", geometry.trim()], withAudio)
    }

    function stopOrCancel(): bool {
        if (regionChooser.active) {
            regionChooser.active = false
            return true
        }
        if (recorderProcess.running) {
            stopRecording()
            return true
        }
        return false
    }

    function stopRecording(): void {
        stopRequested = true
        // The transient service outlives this QML generation long enough to finalise the file.
        Quickshell.execDetached(["systemctl", "--user", "kill", "--kill-who=main", "--signal=SIGINT", recorderUnit])
    }

    function supervisedCommand(command: var): var {
        return [
            "systemd-run",
            "--user",
            `--unit=${recorderUnit}`,
            "--collect",
            "--quiet",
            "--wait",
            "--service-type=exec",
            "--"
        ].concat(command)
    }

    function microphoneName(): string {
        const configured = ConfigOptions.recorder.microphone
        return configured.length > 0 ? configured : (Audio.source?.name ?? "")
    }

    function prepareRecording(captureArguments: var, withAudio: bool): void {
        const videosDirectory = FileUtils.trimFileProtocol(Directories.videos)
        const recordingDirectory = withAudio || captureArguments.includes("--geometry") ? videosDirectory : `${videosDirectory}/debug`
        outputPath = `${recordingDirectory}/recording_${timestamp()}.${withAudio ? "mov" : "mp4"}`
        const recorderArguments = ["--pixel-format", withAudio ? "yuv422p" : "yuv420p"]
        // Resolve on Linux can import DNxHR and MP3 directly from MOV.
        if (withAudio) {
            const frameRate = Math.round(Number(Hyprland.focusedMonitor?.lastIpcObject.refreshRate ?? 0))
            if (!Number.isFinite(frameRate) || frameRate <= 0) {
                notify("Recording cancelled", "Could not determine the monitor refresh rate")
                return
            }
            // Parallel encoding keeps DNxHR from falling behind at high refresh rates.
            // DNxHR decodes as BT.709; convert RGB with that matrix and label the limited YUV range.
            recorderArguments.push("-D", "-r", String(frameRate), "-c", "dnxhd", "-p", "profile=dnxhr_lb", "-p", "color_range=tv", "-p", "threads=8", "-F", "scale=out_color_matrix=bt709:out_range=tv,format=yuv422p", "-C", "libmp3lame")
        } else {
            // Match the screen's RGB colours and tell players how to decode the YUV video.
            recorderArguments.push("-p", "color_range=tv", "-p", "colorspace=bt709", "-F", "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p")
        }
        recorderArguments.push("-f", outputPath, ...captureArguments)

        if (!withAudio) {
            pendingCommand = ["wf-recorder"].concat(recorderArguments)
        } else {
            const sinkName = Audio.sink?.name ?? ""
            if (!Audio.sink?.ready || sinkName.length === 0) {
                notify("Recording cancelled", "The default audio output is not ready")
                pendingCommand = []
                return
            }
            const microphone = microphoneName()
            if (microphone.length === 0) {
                notify("Recording cancelled", "No microphone source is available")
                pendingCommand = []
                return
            }
            pendingCommand = [`${Directories.scriptPath}/Audio/record-mix.sh`, microphone, `${sinkName}.monitor`].concat(recorderArguments)
        }

        createDirectoryProcess.command = ["mkdir", "-p", recordingDirectory]
        createDirectoryProcess.running = true
    }

    Process {
        id: createDirectoryProcess
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.notify("Recording cancelled", "Could not create the recording directory")
                root.pendingCommand = []
                return
            }

            recorderProcess.command = root.supervisedCommand(root.pendingCommand)
            root.pendingCommand = []
            root.stopRequested = false
            recorderProcess.running = true
        }
    }

    Loader {
        id: regionChooser
        active: false
        sourceComponent: RegionSelection {
            acceptText: qsTr("Start recording")
            dimensionStep: 2
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            onCancelled: regionChooser.active = false
            onAccepted: geometry => {
                regionChooser.active = false
                root.startRegion(geometry, false)
            }
        }
    }

    Process {
        id: recorderProcess
        stdout: SplitParser {
            onRead: line => console.log(`[Recorder] ${line}`)
        }
        stderr: SplitParser {
            onRead: line => console.log(`[Recorder] ${line}`)
        }
        onStarted: root.notify("Starting recording", root.outputPath.split("/").pop())
        onExited: (exitCode, exitStatus) => {
            if (root.stopRequested || exitCode === 0)
                root.notify("Recording stopped", "The recording was saved")
            else
                root.notify("Recording failed", `The recorder exited with code ${exitCode}`)
            root.stopRequested = false
        }
    }

    IpcHandler {
        target: "recorder"

        function toggleRegion(): void {
            root.toggleRegion()
        }

        function toggleFullscreen(): void {
            root.toggleFullscreen(false)
        }

        function toggleFullscreenAudio(): void {
            root.toggleFullscreen(true)
        }

        function startRegion(geometry: string): void {
            root.startRegion(geometry, false)
        }

        function stop(): void {
            root.stopOrCancel()
        }
    }
}
