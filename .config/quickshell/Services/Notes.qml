pragma Singleton
pragma ComponentBehavior: Bound

import qs.Modules.Common
import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property alias model: folderModel
    property int pendingJobs: 0
    readonly property bool generating: pendingJobs > 0

    function add(content) {
        const now = new Date()
        writer.path = `${Directories.notesPath}/${Qt.formatDateTime(now, "yyyy-MM-dd-HHmmss-zzz")}.md`
        const text = `---\ncreated_at: ${now.toISOString()}\ntitle: ${JSON.stringify(fallbackTitle(content))}\n---\n${content}\n`
        writer.setText(text)
        generateMetadata(writer.path, text)
    }

    function generateMetadata(path, text) {
        if (!ConfigOptions.notes.aiEnabled || !path || !parse(text).body.trim())
            return
        const job = titleJob.createObject(root, { "filePath": path, "originalText": text })
        if (job)
            pendingJobs++
    }

    function regenerate(path) {
        reader.path = path
        reader.reload()
        generateMetadata(path, reader.text())
    }

    function remove(path) {
        Quickshell.execDetached(["rm", "--", path])
    }

    function parse(text) {
        const frontMatter = text.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/)
        const created = frontMatter?.[1].match(/^created_at:\s*(.+?)\s*$/m)
        const createdAt = created ? new Date(created[1]) : null
        const body = text.slice(frontMatter ? frontMatter[0].length : 0).replace(/\s+$/, "")
        const titleLine = frontMatter?.[1].match(/^title:\s*(.+?)\s*$/m)
        let title = titleLine ? titleLine[1] : ""
        if (title.startsWith('"')) {
            try {
                title = JSON.parse(title)
            } catch (error) {
                title = ""
            }
        }
        return {
            "createdAt": createdAt && !isNaN(createdAt) ? createdAt : null,
            "title": typeof title === "string" && title.trim() ? title.trim() : fallbackTitle(body),
            "body": body,
        }
    }

    function fallbackTitle(content) {
        const firstLine = content.split(/\r?\n/).find(line => line.trim()) ?? ""
        const title = firstLine.replace(/^\s*#+\s+/, "").trim()
        return title.length > 80 ? `${title.slice(0, 77).replace(/\s+$/, "")}…` : title || qsTr("Untitled note")
    }

    function applyMetadata(text, metadata) {
        const front = text.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/)
        const newline = text.startsWith("---\r\n") ? "\r\n" : "\n"
        let header = front ? front[1] : ""
        if (typeof metadata.title === "string" && metadata.title.trim()) {
            const title = `title: ${JSON.stringify(metadata.title)}`
            header = /^title:/m.test(header) ? header.replace(/^title:[^\r\n]*/m, () => title)
                : header + (header ? newline : "") + title
        }
        if (Array.isArray(metadata.tags) && metadata.tags.every(tag => typeof tag === "string")) {
            const existing = header.match(/^tags:[^\r\n]*(?:\r?\n[ \t]*-[ \t]+[^\r\n]*)*/m)
            let tags = []
            try {
                if (existing) {
                    const value = existing[0].replace(/^tags:[ \t]*/, "").trim()
                    const entries = value.startsWith("[") && value.endsWith("]")
                        ? value.slice(1, -1).split(",")
                        : value.startsWith("-") ? value.split(/\r?\n/).map(line => line.replace(/^\s*-\s+/, "")) : [value]
                    tags = entries.filter(entry => entry.trim()).map(entry => {
                        const tag = entry.trim()
                        if (tag.startsWith('"'))
                            return JSON.parse(tag)
                        if (tag.startsWith("'") && tag.endsWith("'"))
                            return tag.slice(1, -1).replace(/''/g, "'")
                        if (!/^[^\s,\[\]{}"'#]+$/.test(tag))
                            throw new Error("Unsupported tag list")
                        return tag
                    })
                    if (tags.some(tag => typeof tag !== "string"))
                        throw new Error("Unsupported tag list")
                }
                // Obsidian treats tag casing as equivalent; keep the user's spelling.
                for (const tag of metadata.tags) {
                    if (!tags.some(existingTag => existingTag.toLowerCase() === tag.toLowerCase()))
                        tags.push(tag)
                }
                const block = tags.length ? `tags:${newline}${tags.map(tag => `  - ${JSON.stringify(tag)}`).join(newline)}` : "tags: []"
                header = existing ? header.replace(existing[0], () => block) : header + (header ? newline : "") + block
            } catch (error) {
                console.warn("[Notes] Existing tag format preserved")
            }
        }
        if (!front)
            return header ? `---${newline}${header}${newline}---${newline}${text}` : text
        const offset = text.indexOf("\n") + 1
        return text.slice(0, offset) + header + text.slice(offset + front[1].length)
    }

    Component {
        id: titleJob

        Process {
            id: job
            required property string filePath
            required property string originalText

            // env lets missing Node.js follow the same cleanup path.
            command: ["env", "node", `${Directories.scriptPath}/note-title.mts`]
            running: ConfigOptions.notes.aiEnabled
            stdinEnabled: true
            onStarted: {
                write(root.parse(originalText).body)
                stdinEnabled = false
            }
            stdout: StdioCollector { id: titleOutput }
            onExited: exitCode => {
                if (ConfigOptions.notes.aiEnabled && exitCode === 0 && titleOutput.text.trim()) {
                    try {
                        const metadata = JSON.parse(titleOutput.text)
                        const updated = root.applyMetadata(originalText, metadata)
                        if (updated !== originalText) {
                            savedNote.reload()
                            if (savedNote.text() === originalText)
                                savedNote.setText(updated)
                        }
                    } catch (error) {
                        console.warn("[Notes] Could not read generated note metadata")
                    }
                }
                root.pendingJobs--
                destroy()
            }

            property FileView savedNote: FileView {
                path: job.filePath
                preload: false
                blockAllReads: true
                blockWrites: true
                atomicWrites: true
                printErrors: false // The note may have been deleted while the request ran.
            }
        }
    }

    FileView {
        id: reader
        preload: false
        blockAllReads: true
        printErrors: false
    }

    FileView {
        id: writer
        preload: false
        blockWrites: true
        atomicWrites: true
    }

    FolderListModel {
        id: folderModel
        nameFilters: ["*.md"]
        showDirs: false
        sortField: FolderListModel.Time // most recently updated files first
    }

    Process {
        running: true
        command: ["mkdir", "-p", Directories.notesPath]
        onExited: folderModel.folder = `file://${Directories.notesPath}` // model ignores folders created later
    }
}
