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
        writer.path = `${Directories.notesPath}/${Qt.formatDateTime(now, "yyyy-MM-dd-HHmmss")}.md`
        writer.setText(`---\ncreated_at: ${now.toISOString()}\n---\n${content}\n`)
    }

    function remove(path) {
        Quickshell.execDetached(["rm", "--", path])
    }

    function parse(text) {
        const frontMatter = text.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/)
        const created = frontMatter?.[1].match(/^created_at:\s*(.+?)\s*$/m)
        const createdAt = created ? new Date(created[1]) : null
        return {
            "createdAt": createdAt && !isNaN(createdAt) ? createdAt : null,
            "body": text.slice(frontMatter ? frontMatter[0].length : 0).replace(/\s+$/, ""),
        }
    }

    FileView {
        id: writer
        preload: false
        blockWrites: true
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
