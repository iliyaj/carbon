.pragma library

function snap(value, enabled, spacing) {
    return enabled ? Math.round(value / spacing) * spacing : value;
}

function pixels(context, x, y, width, height) {
    x = Math.max(0, Math.min(Math.floor(x), width - 1));
    y = Math.max(0, Math.min(Math.floor(y), height - 1));
    const left = Math.max(0, x - 5), top = Math.max(0, y - 5);
    const w = Math.min(width, x + 6) - left, h = Math.min(height, y + 6) - top;
    const data = context.getImageData(left, top, w, h).data;
    const colors = [];
    for (let row = -5; row <= 5; ++row) {
        for (let col = -5; col <= 5; ++col) {
            const xx = x + col, yy = y + row;
            if (xx < 0 || yy < 0 || xx >= width || yy >= height) { colors.push("transparent"); continue; }
            const index = ((yy - top) * w + xx - left) * 4;
            colors.push("#" + [data[index], data[index + 1], data[index + 2]].map(v => v.toString(16).padStart(2, "0")).join(""));
        }
    }
    return { x: x, y: y, colors: colors, color: colors[60] };
}

function keyboardRegion(region, action, width, height, step) {
    const horizontal = /Left|Right|left|right/.test(action);
    const direction = /Left|Up|left|up/.test(action) ? -step : step;
    let x = region.x, y = region.y, w = region.width, h = region.height;
    if (action.startsWith("symmetric")) {
        if (horizontal) {
            const delta = Math.max(-Math.floor((w - step) / (2 * step)) * step, Math.min(direction, x, width - x - w));
            x -= delta; w += 2 * delta;
        } else {
            const delta = Math.max(-Math.floor((h - step) / (2 * step)) * step, Math.min(direction, y, height - y - h));
            y -= delta; h += 2 * delta;
        }
    } else if (action.startsWith("resize")) {
        if (horizontal) w = Math.max(step, Math.min(width - x, w + direction));
        else h = Math.max(step, Math.min(height - y, h + direction));
        w = Math.floor(w / step) * step; h = Math.floor(h / step) * step;
    } else {
        if (horizontal) x = Math.max(0, Math.min(width - w, x + direction));
        else y = Math.max(0, Math.min(height - h, y + direction));
    }
    return { x: x, y: y, width: w, height: h };
}
