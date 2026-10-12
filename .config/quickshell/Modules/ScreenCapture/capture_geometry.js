.pragma library

function layout(monitors, screens) {
    return monitors.filter(m => !m.disabled && m.dpmsStatus !== false && m.mirrorOf === "none").map(m => {
        const screen = screens.find(s => s.name === m.name);
        if (!screen) throw new Error("Monitor is unavailable: " + m.name);
        const rotated = Number(m.transform) % 2 === 1;
        const nativeWidth = rotated ? m.height : m.width;
        const nativeHeight = rotated ? m.width : m.height;
        return { name: m.name, x: m.x, y: m.y, width: screen.width, height: screen.height,
            nativeWidth: nativeWidth, nativeHeight: nativeHeight, scale: m.scale, transform: m.transform };
    }).sort((a, b) => a.name.localeCompare(b.name));
}

function captureArea(monitors, target, monitor) {
    const selected = target === "desktop" ? monitors : monitors.filter(m => m.name === monitor);
    if (selected.length === 0) throw new Error("The requested monitor is unavailable.");
    const x = Math.min.apply(null, selected.map(m => m.x));
    const y = Math.min.apply(null, selected.map(m => m.y));
    const right = Math.max.apply(null, selected.map(m => m.x + m.width));
    const bottom = Math.max.apply(null, selected.map(m => m.y + m.height));
    return { x: x, y: y, width: right - x, height: bottom - y,
        scale: Math.max.apply(null, selected.map(m => m.nativeWidth / m.width)),
        signature: JSON.stringify(selected) };
}

function validRegion(region, width, height) {
    return region && [region.x, region.y, region.width, region.height].every(Number.isInteger)
        && region.x >= 0 && region.y >= 0 && region.width > 0 && region.height > 0
        && region.x + region.width <= width && region.y + region.height <= height;
}

function rememberedRegion(previous, target, monitor, area, width, height) {
    if (!previous || previous.target !== target || previous.monitor !== monitor
        || previous.signature !== area.signature || previous.imageWidth !== width || previous.imageHeight !== height
        || !validRegion(previous.region, width, height))
        throw new Error("The last region does not match this monitor layout. Select a new region.");
    return previous.region;
}

function request(options) {
    if (!options || typeof options !== "object" || Array.isArray(options)) throw new Error("Capture options must be an object.");
    const target = options.target ?? "active";
    const selection = options.selection ?? "region";
    const delay = options.delay ?? 0;
    if (!["active", "monitor", "desktop"].includes(target)) throw new Error("Choose active, monitor or desktop capture.");
    if (target === "monitor" && (typeof options.monitor !== "string" || !options.monitor)) throw new Error("Choose a monitor.");
    if (!["region", "all", "last"].includes(selection)) throw new Error("Choose region, all or last selection.");
    if (!Number.isInteger(delay) || delay < 0 || delay > 86400) throw new Error("Delay must be a whole number of seconds from 0 to 86400.");
    if (options.region !== undefined && options.region !== null &&
        !validRegion(options.region, Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER))
        throw new Error("Initial region must have non-negative integer x/y and positive integer width/height.");
    for (const key of ["edit", "concurrent", "acceptOnSelection", "wait"])
        if (options[key] !== undefined && typeof options[key] !== "boolean") throw new Error(key + " must be true or false.");
    const outputs = options.outputs ?? ["save", "copy"];
    if (!Array.isArray(outputs) || outputs.some(action => !["save", "copy", "pin"].includes(action))
        || new Set(outputs).size !== outputs.length) throw new Error("Outputs must be unique save, copy or pin actions.");
    if (options.path !== undefined && (typeof options.path !== "string" || !options.path.startsWith("/") || options.path.includes("\u0000")))
        throw new Error("The output path must be absolute.");
    if (options.image !== undefined && (typeof options.image !== "string" || !options.image.startsWith("/") || options.image.includes("\u0000")))
        throw new Error("The image path must be absolute.");
    const format = options.format ?? "png";
    if (!["png", "jpeg", "webp", "bmp", "tiff", "avif", "ppm", "pgm", "pbm", "xbm", "xpm"].includes(format)) throw new Error("Unsupported image format.");
    const quality = options.quality ?? 90;
    if (!Number.isInteger(quality) || quality < 1 || quality > 100) throw new Error("Quality must be from 1 to 100.");
    const clipboardFormat = options.clipboardFormat ?? "png";
    if (!["png", "jpeg"].includes(clipboardFormat)) throw new Error("Clipboard format must be png or jpeg.");
    return { target: target, monitor: target === "monitor" ? options.monitor : "", delay: delay,
        selection: selection, region: options.region ?? null, edit: options.image ? true : options.edit ?? false,
        concurrent: options.concurrent ?? false, acceptOnSelection: options.acceptOnSelection ?? false,
        wait: options.wait ?? false, outputs: outputs, path: options.path ?? "", format: format,
        quality: quality, clipboardFormat: clipboardFormat, image: options.image ?? "" };
}
