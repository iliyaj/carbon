import "root:/Modules/Common"
import "root:/Modules/Common/Functions"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    readonly property bool recording: recorderProcess.running
    readonly property bool selectingRegion: regionProcess.running
    property bool stopRequested: false
    property var pendingCommand: []
    property string outputPath: ""

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
        regionProcess.running = true
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
        if (recorderProcess.running) {
            stopRequested = true
            recorderProcess.signal(2)
            return true
        }
        if (regionProcess.running) {
            regionProcess.signal(15)
            return true
        }
        return false
    }

    function microphoneName(): string {
        const configured = ConfigOptions.recorder.microphone
        return configured.length > 0 ? configured : (Audio.source?.name ?? "")
    }

    function prepareRecording(captureArguments: var, withAudio: bool): void {
        const videosDirectory = FileUtils.trimFileProtocol(Directories.videos)
        outputPath = `${videosDirectory}/recording_${timestamp()}.mp4`
        const recorderArguments = ["--pixel-format", "yuv420p", "-f", outputPath].concat(captureArguments)

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

        createDirectoryProcess.command = ["mkdir", "-p", videosDirectory]
        createDirectoryProcess.running = true
    }

    Process {
        id: createDirectoryProcess
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.notify("Recording cancelled", "Could not create the Videos directory")
                root.pendingCommand = []
                return
            }

            recorderProcess.command = root.pendingCommand
            root.pendingCommand = []
            root.stopRequested = false
            recorderProcess.running = true
        }
    }

    Process {
        id: regionProcess
        // Keep slurp's stdin closed.
        command: ["sh", "-c", "exec slurp </dev/null"]
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            const geometry = stdout.text.trim()
            if (exitCode === 0 && geometry.length > 0)
                root.startRegion(geometry, false)
            else
                root.notify("Recording cancelled", "Selection was cancelled")
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
