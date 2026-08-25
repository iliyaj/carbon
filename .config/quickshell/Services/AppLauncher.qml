pragma Singleton

import Quickshell

Singleton {
    id: root

    // Keep GUI applications outside quickshell.service so a shell restart cannot kill them.
    function launchDesktopEntry(entry): void {
        if (!entry)
            return;

        const desktopId = String(entry.id ?? "").replace(/\.desktop$/, "");
        if (desktopId !== "") {
            Quickshell.execDetached([
                "systemd-run", "--user", "--scope", "--collect",
                "--slice=app.slice", "--", "gtk-launch", desktopId
            ]);
            return;
        }

        launchCommand(entry.exec);
    }

    function launchCommand(command): void {
        if (!command || command.length === 0)
            return;

        Quickshell.execDetached([
            "systemd-run", "--user", "--scope", "--collect",
            "--slice=app.slice", "--"
        ].concat(command));
    }
}
