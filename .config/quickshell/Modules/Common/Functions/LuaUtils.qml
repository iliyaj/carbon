pragma Singleton
import Quickshell

/**
 * Helpers for building Lua source passed to Hyprland's dispatcher.
 */

Singleton {
    id: root

    /**
     * Wraps a value in a Lua long-bracket string literal, widening the bracket
     * level until it cannot collide with the content.
     * @param {any} value
     * @returns {string}
     */
    function stringLiteral(value) {
        const text = String(value);
        let equals = "";

        while (text.includes(`]${equals}]`))
            equals += "=";

        return `[${equals}[${text}]${equals}]`;
    }
}
