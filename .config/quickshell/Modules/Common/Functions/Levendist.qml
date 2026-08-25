pragma Singleton
import Quickshell
import "levendist.js" as LevendistJs

/**
 * Wrapper for levendist.js to play nicely with Quickshell's imports
 */

Singleton {
    function computeScore(...args) {
        return LevendistJs.computeScore(...args)
    }

    function computeTextMatchScore(...args) {
        return LevendistJs.computeTextMatchScore(...args)
    }
}
