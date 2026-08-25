pragma Singleton
import Quickshell

/**
 * Utility functions for file paths and URLs.
 */

Singleton {
    id: root

    /**
     * Trims the File protocol off the input string
     * @param {string} str
     * @returns {string}
     */
    function trimFileProtocol(str) {
        return str.startsWith("file://") ? str.slice(7) : str;
    }
}
