pragma Singleton
import Quickshell

/**
 * Conversion between Qt objects and plain JS objects, used for config persistence.
 */

Singleton {
    id: root

    /**
     * Recursively converts a Qt object into a plain JS object or array.
     * @param { any } qtObj
     * @returns { any }
     */
    function toPlainObject(qtObj) {
        if (qtObj === null || typeof qtObj !== "object") return qtObj;

        // Handle true arrays
        if (Array.isArray(qtObj)) {
            return qtObj.map(item => root.toPlainObject(item));
        }

        // Empty Qt sequences (e.g. list<string>) must serialize as [], not fall
        // through to the object branch and get saved as {}
        if (typeof qtObj.length === "number" && qtObj.length === 0) {
            return [];
        }

        // Handle array-like Qt objects (e.g., have length and numeric keys)
        if (
            typeof qtObj.length === "number" &&
            qtObj.length > 0 &&
            Object.keys(qtObj).every(
                key => !isNaN(key) || key === "length"
            )
        ) {
            let arr = [];
            for (let i = 0; i < qtObj.length; i++) {
                arr.push(root.toPlainObject(qtObj[i]));
            }
            return arr;
        }

        const result = ({});
        for (let key in qtObj) {
            if (
                typeof qtObj[key] !== "function" &&
                !key.startsWith("objectName") &&
                !key.startsWith("children") &&
                !key.startsWith("object") &&
                !key.startsWith("parent") &&
                !key.startsWith("metaObject") &&
                !key.startsWith("destroyed") &&
                !key.startsWith("reloadableId")
            ) {
                result[key] = root.toPlainObject(qtObj[key]);
            }
        }
        return result;
    }

    /**
     * Recursively merges a plain JS object into an existing Qt object.
     * @param { any } qtObj
     * @param { any } jsonObj
     */
    function applyToQtObject(qtObj, jsonObj) {
        if (!qtObj || typeof jsonObj !== "object" || jsonObj === null) return;

        // Detect array-like Qt objects
        const isQtArrayLike = obj => {
            return obj && typeof obj === "object" &&
                typeof obj.length === "number" &&
                obj.length > 0 &&
                Object.keys(obj).every(key => !isNaN(key) || key === "length");
        };

        // Rebuilding a list notifies once per element, so an unchanged list must be left alone
        const sameList = (list, jsonList) => {
            if (list.length !== jsonList.length) return false;
            for (let i = 0; i < jsonList.length; i++) {
                if (list[i] !== jsonList[i]) return false;
            }
            return true;
        };

        // If both are arrays or array-like, update in place or replace
        if ((Array.isArray(qtObj) || isQtArrayLike(qtObj)) && Array.isArray(jsonObj)) {
            if (sameList(qtObj, jsonObj)) return;
            qtObj.length = 0;
            for (let i = 0; i < jsonObj.length; i++) {
                qtObj.push(jsonObj[i]);
            }
            return;
        }

        // If target is array or array-like but source is not, clear
        if ((Array.isArray(qtObj) || isQtArrayLike(qtObj)) && !Array.isArray(jsonObj)) {
            qtObj.length = 0;
            return;
        }

        // If source is array but target is not, assign directly if possible
        if (!(Array.isArray(qtObj) || isQtArrayLike(qtObj)) && Array.isArray(jsonObj)) {
            return jsonObj;
        }

        // Distinguish nested QtObject config sections (merged recursively) from
        // plain JS values like dictionaries in `property var` (assigned wholesale,
        // so keys added or removed in the config file are respected)
        const isQtObject = obj => {
            return obj && typeof obj === "object" && typeof obj.objectName === "string";
        };

        for (let key in jsonObj) {
            if (!qtObj.hasOwnProperty(key)) continue;
            const value = qtObj[key];
            const jsonValue = jsonObj[key];
            if ((Array.isArray(value) || isQtArrayLike(value)) && Array.isArray(jsonValue)) {
                if (sameList(value, jsonValue)) continue;
                value.length = 0;
                for (let i = 0; i < jsonValue.length; i++) {
                    value.push(jsonValue[i]);
                }
            } else if (isQtObject(value)) {
                root.applyToQtObject(value, jsonValue);
            } else if (value !== jsonValue) {
                qtObj[key] = jsonValue;
            }
        }
    }
}
