pragma Singleton
pragma ComponentBehavior: Bound

import qs.Modules.Common
import qs.Modules.Common.Functions
import qs.Modules.ScreenCapture
import "../Modules/ScreenCapture/capture_geometry.js" as CaptureGeometry
import "../Modules/ScreenCapture/screenshot_preferences.js" as ScreenshotPreferences
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var sessions: []
    property int nextId: 1
    readonly property bool busy: sessions.some(session => !session.terminal)
    readonly property int countdown: sessions.reduce((value, session) => Math.max(value, session.countdown), 0)
    readonly property string cacheDirectory: FileUtils.trimFileProtocol(`${Directories.cache}/carbon`)
    readonly property string screenshotDirectory: ConfigOptions.screenshot.directory || FileUtils.trimFileProtocol(`${Directories.pictures}/Screenshots`)
    readonly property var lastRegion: PersistentStates.screenshot.lastRegion
    property string lastError: ""

    PersistentProperties {
        id: resources
        reloadableId: "screenClipResources"
        property list<string> paths: []
        onReloaded: {
            root.cleanup(Array.from(paths))
            paths = []
        }
    }

    function cleanup(paths): void {
        if (paths?.length > 0) Quickshell.execDetached(["rm", "-f", "--"].concat(Array.from(paths)))
    }

    function remember(region): void {
        PersistentStateManager.setState("screenshot.lastRegion", region)
    }

    function reject(message): string {
        lastError = message
        return ""
    }

    function requestCapture(options): string {
        let request
        const preferences = ConfigOptions.screenshot
        try { request = CaptureGeometry.request(Object.assign({ delay: preferences.delay, concurrent: preferences.concurrent,
            acceptOnSelection: preferences.acceptOnSelection, format: preferences.format,
            quality: preferences.quality, clipboardFormat: preferences.clipboardFormat }, options)) }
        catch (error) { return reject(error.message) }
        if (busy && !request.concurrent) return reject(qsTr("A capture is already active. Finish or cancel it, or enable independent sessions."))
        lastError = ""
        return createSession(request, request.image)
    }

    function createSession(request, imagePath): string {
        const id = Quickshell.processId + "-" + Date.now() + "-" + nextId++
        const scratch = cacheDirectory + "/capture-" + Quickshell.processId + "-" + Date.now() + "-" + id
        const session = captureSession.createObject(root, { owner: root, sessionId: id,
            request: request, scratchPath: scratch, imagePath: imagePath })
        if (!session) return reject(qsTr("Could not create the capture session."))
        resources.paths = Array.from(resources.paths).concat(session.ownedPaths)
        session.finished.connect(root.releaseSession)
        session.failed.connect(root.notifyFailure)
        sessions = sessions.concat([session])
        Qt.callLater(session.start)
        return id
    }

    function releaseSession(id, force = false): void {
        const session = sessions.find(item => item.sessionId === id)
        if (!session) return
        if (session.request.wait && !force) { showNextSelection(); return }
        const owned = session.ownedPaths
        cleanup(owned)
        resources.paths = Array.from(resources.paths).filter(path => !owned.includes(path))
        sessions = sessions.filter(item => item !== session)
        Qt.callLater(() => session.destroy())
        showNextSelection()
    }

    function showNextSelection(): void {
        if (sessions.some(session => session.state === "selecting")) return
        const queued = sessions.filter(session => session.state === "waiting-capture")
        if (queued.length > 0) {
            for (const session of queued) session.takeSnapshot()
            return
        }
        // Keep selector chrome out of snapshots still being captured.
        if (sessions.some(session => ["preparing", "capturing"].includes(session.state))) return
        const next = sessions.find(session => session.state === "waiting")
        if (next) next.select()
    }

    function cancel(id = "") {
        for (const session of sessions.slice())
            if (!id || session.sessionId === id) session.cancel()
    }

    function result(id): string {
        const session = sessions.find(item => item.sessionId === id)
        return JSON.stringify(session ? session.result() : { id: id, state: "missing", error: "The capture was released or the shell reloaded." })
    }

    function cancelDelayed(): void {
        for (const session of sessions.slice())
            if (session.state === "delay") session.cancel()
    }

    function notifyFailure(message): void {
        lastError = message
        if (ConfigOptions.screenshot.notifications) Quickshell.execDetached(["notify-send", "-a", "Screen clipping", "Screenshot failed", message])
    }

    function open(delayed: bool): void {
        if (!requestCapture({ delay: delayed ? ConfigOptions.screenshot.delayedDelay : ConfigOptions.screenshot.delay })) notifyFailure(lastError)
    }

    function editImage(path: string): void {
        if (path.length === 0) return
        const local = path.startsWith("file://") ? decodeURIComponent(path.slice(7)) : path
        if (!requestCapture({ image: local, edit: true, delay: 0 })) notifyFailure(lastError)
    }

    function showOptions(): void {
        options.active = true
    }

    Component { id: captureSession; CaptureSession {} }

    Loader {
        id: options
        active: false
        sourceComponent: CaptureOptions {
            owner: root
            onDismissed: options.active = false
        }
    }

    IpcHandler {
        target: "screenClip"
        function editImage(path: string): void { root.editImage(path) }
        function open(): void { root.open(false) }
        function openDelayed(): void { root.open(true) }
        function options(): void { root.showOptions() }
        function cancel(id: string): void { root.cancel(id) }
        function result(id: string): string { return root.result(id) }
        function release(id: string): void {
            const session = root.sessions.find(item => item.sessionId === id)
            if (session?.terminal) root.releaseSession(id, true)
        }
        function desktop(copy: bool): void {
            if (!root.requestCapture({ target: "desktop", selection: "all", outputs: copy ? ["copy"] : ["save"] })) root.notifyFailure(root.lastError)
        }
        function editor(): void {
            if (!root.requestCapture({ edit: true })) root.notifyFailure(root.lastError)
        }
        function preferences(patch: string): string {
            try {
                if (ConfigLoader.firstLoad) throw new Error("Configuration has not loaded yet.")
                const values = ScreenshotPreferences.validate(JSON.parse(patch))
                for (const key of Object.keys(values)) ConfigLoader.setConfigValueAndSave("screenshot." + key, values[key])
                ConfigLoader.flushConfig()
                return JSON.stringify({ preferences: ObjectUtils.toPlainObject(ConfigOptions.screenshot), error: "" })
            } catch (error) { return JSON.stringify({ error: error.message }) }
        }
        function request(options: string): string {
            try {
                const id = root.requestCapture(JSON.parse(options))
                return JSON.stringify({ id: id, error: id ? "" : root.lastError })
            } catch (error) { return JSON.stringify({ id: "", error: error.message }) }
        }
        function status(): string {
            return JSON.stringify(root.sessions.map(session => ({ id: session.sessionId, state: session.state, countdown: session.countdown })))
        }
    }
}
