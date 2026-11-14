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

    function add(content) {
        const now = new Date()
        writer.path = `${Directories.notesPath}/${Qt.formatDateTime(now, "yyyy-MM-dd-HHmmss-zzz")}.md`
        const text = `---\ncreated_at: ${now.toISOString()}\ntitle: ${JSON.stringify(fallbackTitle(content))}\n---\n${content}\n`
        writer.setText(text)
        titleJob.createObject(root, { "filePath": writer.path, "originalText": text })
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

    Component {
        id: titleJob

        Process {
            id: job
            required property string filePath
            required property string originalText

            // env lets missing Node.js follow the same cleanup path.
            command: ["env", "node", `${Directories.scriptPath}/note-title.mts`]
            running: true
            stdinEnabled: true
            onStarted: {
                write(root.parse(originalText).body)
                stdinEnabled = false
            }
            stdout: StdioCollector { id: titleOutput }
            onExited: exitCode => {
                if (exitCode === 0 && titleOutput.text.trim()) {
                    try {
                        const metadata = JSON.parse(titleOutput.text)
                        let updated = originalText
                        if (typeof metadata.title === "string" && metadata.title.trim())
                            updated = updated.replace(/^title:.*$/m, () => `title: ${JSON.stringify(metadata.title)}`)
                        if (Array.isArray(metadata.tags) && metadata.tags.every(tag => typeof tag === "string")) {
                            const tags = metadata.tags.length ? `tags:\n${metadata.tags.map(tag => `  - ${JSON.stringify(tag)}`).join("\n")}` : "tags: []"
                            updated = updated.replace("\n---\n", () => `\n${tags}\n---\n`)
                        }
                        if (updated !== originalText) {
                            savedNote.reload()
                            if (savedNote.text() === originalText)
                                savedNote.setText(updated)
                        }
                    } catch (error) {
                        console.warn("[Notes] Could not read generated note metadata")
                    }
                }
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
        id: writer
        preload: false
        blockWrites: true
        atomicWrites: true
    }

    FolderListModel {
        id: folderModel
        nameFilters: ["*.md"]
        showDirs: false
        sortField: FolderListModel.Name
        sortReversed: true // newest timestamp first
    }

    Process {
        running: true
        command: ["mkdir", "-p", Directories.notesPath]
        onExited: folderModel.folder = `file://${Directories.notesPath}` // model ignores folders created later
    }
}
