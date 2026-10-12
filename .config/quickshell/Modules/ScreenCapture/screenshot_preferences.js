.pragma library

var tools = ["select", "pen", "line", "arrow", "rect", "fill", "ellipse", "marker", "text", "counter", "conceal", "pixelate", "blur", "solid", "invert"];
var shortcuts = { select: "V", pen: "P", line: "L", arrow: "A", rect: "R", fill: "F", ellipse: "E",
    marker: "M", text: "T", counter: "N", conceal: "H", pixelate: "B", blur: "U", solid: "X", invert: "I",
    undo: "Ctrl+Z", redo: "Ctrl+Shift+Z", delete: "Delete", editText: "Enter", commitText: "Ctrl+Enter",
    copy: "Ctrl+C", save: "Ctrl+S", saveAs: "Ctrl+Shift+S", pin: "Ctrl+P", open: "Ctrl+O",
    objects: "D", options: "Tab", help: "F1", sample: "C", magnifier: "G", cancel: "Escape",
    saveCopy: "Ctrl+Alt+S", copyPath: "Ctrl+Shift+C", outputOptions: "Alt+O", rounded: "J",
    larger: "+", smaller: "-", all: "Ctrl+A", left: "Left", right: "Right", up: "Up", down: "Down",
    resizeLeft: "Shift+Left", resizeRight: "Shift+Right", resizeUp: "Shift+Up", resizeDown: "Shift+Down",
    symmetricLeft: "Ctrl+Shift+Left", symmetricRight: "Ctrl+Shift+Right", symmetricUp: "Ctrl+Shift+Up", symmetricDown: "Ctrl+Shift+Down" };

// This is also the settings form schema; CLI and watched config use the same validator.
var fields = [
    { key: "toolOrder", label: "Visible tools, in order (JSON array)", group: "Tools", type: "tools" },
    { key: "defaultTool", label: "Initial tool", group: "Tools", choices: tools },
    { key: "rememberStyle", label: "Restore last tool and styling", group: "Tools", type: "bool" },
    { key: "color", label: "Drawing colour (#RRGGBB)", group: "Tools", type: "color" },
    { key: "strokeWidth", label: "Stroke / effect size", group: "Tools", type: "int", min: 1, max: 100 },
    { key: "rounded", label: "Rounded rectangles", group: "Tools", type: "bool" },
    { key: "palette", label: "Palette (JSON colour array)", group: "Tools", type: "palette" },
    { key: "fontFamily", label: "Font family (empty uses Carbon theme)", group: "Text", type: "string" },
    { key: "fontSize", label: "Font size in image pixels", group: "Text", type: "int", min: 1, max: 100 },
    { key: "fontBold", label: "Bold", group: "Text", type: "bool" },
    { key: "fontItalic", label: "Italic", group: "Text", type: "bool" },
    { key: "fontUnderline", label: "Underline", group: "Text", type: "bool" },
    { key: "fontStrikeout", label: "Strike-through", group: "Text", type: "bool" },
    { key: "fontAlign", label: "Alignment", group: "Text", choices: ["left", "center", "right"] },
    { key: "delay", label: "Default capture delay (seconds)", group: "Capture", type: "int", min: 0, max: 86400 },
    { key: "delayedDelay", label: "Delayed bar button (seconds)", group: "Capture", type: "int", min: 0, max: 86400 },
    { key: "concurrent", label: "Allow independent captures", group: "Capture", type: "bool" },
    { key: "acceptOnSelection", label: "Accept a new selection on release", group: "Capture", type: "bool" },
    { key: "directory", label: "Save folder (absolute; empty uses Pictures/Screenshots)", group: "Output", type: "directory" },
    { key: "filenamePattern", label: "Filename pattern (Qt date format)", group: "Output", type: "filename" },
    { key: "format", label: "File encoding", group: "Output", choices: ["png", "jpeg", "webp", "bmp", "tiff", "avif", "ppm", "pgm", "pbm", "xbm", "xpm"] },
    { key: "quality", label: "Encoder quality", group: "Output", type: "int", min: 1, max: 100 },
    { key: "clipboardFormat", label: "Image clipboard encoding", group: "Output", choices: ["png", "jpeg"] },
    { key: "saveAfterCopy", label: "Also save when copying an image", group: "Output", type: "bool" },
    { key: "copyPathAfterSave", label: "Copy file path after saving", group: "Output", type: "bool" },
    { key: "pinSmoothing", label: "Smooth scaling for new pins", group: "Appearance", type: "bool" },
    { key: "overlayOpacity", label: "Selection overlay dimming (0–1)", group: "Appearance", type: "real", min: 0, max: 1 },
    { key: "contrast", label: "Screenshot controls", group: "Appearance", choices: ["theme", "high"] },
    { key: "showHelp", label: "Show shortcut help when opening the editor", group: "Appearance", type: "bool" },
    { key: "notifications", label: "Screenshot notifications", group: "Appearance", type: "bool" },
    { key: "gridEnabled", label: "Snap mouse gestures to the pixel grid", group: "Precision", type: "bool" },
    { key: "gridSpacing", label: "Grid spacing in image pixels", group: "Precision", type: "int", min: 1, max: 256 },
    { key: "magnifier", label: "Show pixel magnifier", group: "Precision", type: "bool" },
    { key: "shortcuts", label: "Local shortcuts", group: "Shortcuts", type: "shortcuts" }
];

function keySequence(value) {
    if (typeof value !== "string") throw new Error("Shortcuts must be key sequence strings.");
    if (value === "") return "";
    if (value === "+" || value === "-") return value;
    const parts = value.split("+").map(part => part.trim());
    const key = parts.pop();
    const modifiers = ["Ctrl", "Alt", "Shift"];
    if (parts.some(part => !modifiers.includes(part)) || new Set(parts).size !== parts.length
        || !/^([A-Z0-9]|F([1-9]|1[0-2])|Left|Right|Up|Down|Enter|Escape|Delete|Backspace|Tab|Space)$/.test(key))
        throw new Error("Use Ctrl/Alt/Shift with a letter, digit, F1–F12, arrow, Enter, Escape, Delete, Backspace, Tab or Space.");
    return modifiers.filter(part => parts.includes(part)).concat([key]).join("+");
}

function bindings(overrides) {
    const result = Object.assign({}, shortcuts);
    if (!overrides || typeof overrides !== "object" || Array.isArray(overrides)) throw new Error("Shortcuts must be an object.");
    for (const key of Object.keys(overrides)) {
        if (!Object.keys(shortcuts).includes(key)) throw new Error("Unknown shortcut action: " + key);
        result[key] = keySequence(overrides[key]);
    }
    const used = {};
    for (const key of Object.keys(result)) {
        const sequence = result[key];
        if (!sequence) continue;
        if (used[sequence]) throw new Error(sequence + " conflicts between " + used[sequence] + " and " + key + ".");
        used[sequence] = key;
    }
    return result;
}

function eventSequence(event, qt) {
    const names = { [qt.Key_Left]: "Left", [qt.Key_Right]: "Right", [qt.Key_Up]: "Up", [qt.Key_Down]: "Down",
        [qt.Key_Return]: "Enter", [qt.Key_Enter]: "Enter", [qt.Key_Escape]: "Escape", [qt.Key_Delete]: "Delete",
        [qt.Key_Backspace]: "Backspace", [qt.Key_Tab]: "Tab", [qt.Key_Backtab]: "Tab", [qt.Key_Space]: "Space" };
    let key = names[event.key] ?? (event.key >= qt.Key_F1 && event.key <= qt.Key_F12 ? "F" + (event.key - qt.Key_F1 + 1)
        : event.key >= 48 && event.key <= 90 ? String.fromCharCode(event.key) : "");
    if (event.key === qt.Key_Plus || event.key === qt.Key_Equal) return "+";
    if (event.key === qt.Key_Minus) return "-";
    const modifiers = [];
    if (event.modifiers & qt.ControlModifier) modifiers.push("Ctrl");
    if (event.modifiers & qt.AltModifier) modifiers.push("Alt");
    if (event.modifiers & qt.ShiftModifier) modifiers.push("Shift");
    return modifiers.concat([key]).join("+");
}

function action(event, overrides, qt) {
    const sequence = eventSequence(event, qt);
    const keys = bindings(overrides);
    return Object.keys(keys).find(key => keys[key] === sequence) ?? "";
}

function validate(patch) {
    if (!patch || typeof patch !== "object" || Array.isArray(patch)) throw new Error("Screenshot preferences must be an object.");
    const result = {};
    for (const key of Object.keys(patch)) {
        const field = fields.find(item => item.key === key);
        if (!field) throw new Error("Unknown screenshot preference: " + key);
        const value = patch[key];
        let valid = true;
        if (field.choices) valid = field.choices.includes(value);
        else if (field.type === "bool") valid = typeof value === "boolean";
        else if (field.type === "int" || field.type === "real") valid = typeof value === "number" && Number.isFinite(value)
            && (field.type !== "int" || Number.isInteger(value)) && value >= field.min && value <= field.max;
        else if (field.type === "tools") valid = Array.isArray(value) && value.length > 0 && new Set(value).size === value.length
            && value.every(tool => tools.includes(tool));
        else if (field.type === "palette") valid = Array.isArray(value) && value.length > 0 && value.length <= 32
            && value.every(color => typeof color === "string" && /^#[0-9a-fA-F]{6}$/.test(color));
        else if (field.type === "shortcuts") bindings(value);
        else {
            valid = typeof value === "string" && !value.includes("\u0000") && value.length <= 4096;
            if (valid && field.type === "color") valid = /^#[0-9a-fA-F]{6}$/.test(value);
            if (valid && field.type === "directory") valid = value === "" || value.startsWith("/");
            if (valid && field.type === "filename") valid = value.trim().length > 0 && !/[/\\]/.test(value) && value !== "." && value !== "..";
        }
        if (!valid) throw new Error("Invalid value for " + field.label + ".");
        result[key] = value;
    }
    return result;
}

function merge(original, updated) {
    const result = Object.assign({}, original);
    for (const key of Object.keys(updated)) {
        const value = updated[key];
        result[key] = value && typeof value === "object" && !Array.isArray(value)
            ? merge(original?.[key] ?? {}, value) : value;
    }
    return result;
}
