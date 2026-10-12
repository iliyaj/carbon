.import "annotation_tools.js" as AnnotationTools

function copy(value) {
    return JSON.parse(JSON.stringify(value));
}

function history(shapes, nextCounter) {
    return { past: [], present: copy({ shapes: shapes, nextCounter: nextCounter }), future: [] };
}

function commit(current, shapes, nextCounter) {
    const next = copy({ shapes: shapes, nextCounter: nextCounter });
    if (JSON.stringify(next) === JSON.stringify(current.present)) return current;
    return { past: current.past.concat([current.present]), present: next, future: [] };
}

function undo(current) {
    if (current.past.length === 0) return current;
    return { past: current.past.slice(0, -1), present: current.past[current.past.length - 1],
        future: [current.present].concat(current.future) };
}

function redo(current) {
    if (current.future.length === 0) return current;
    return { past: current.past.concat([current.present]), present: current.future[0],
        future: current.future.slice(1) };
}

function clamp(value, low, high) {
    return Math.max(low, Math.min(value, high));
}

function bounds(shape, detail) {
    if (shape.type === "text")
        return { x: shape.x1, y: shape.y1, width: shape.x2 - shape.x1, height: shape.y2 - shape.y1 };
    if (AnnotationTools.isEffect(shape.type))
        return AnnotationTools.effectBox(shape, Infinity, Infinity);
    let points = shape.type === "pen" ? shape.points
        : [{ x: shape.x1, y: shape.y1 }, { x: shape.x2, y: shape.y2 }];
    let padding = shape.type === "fill" ? 0 : shape.width / 2;
    if (shape.type === "arrow") {
        points = detail.polygon.concat([{ x: shape.x1, y: shape.y1 }]);
        padding = detail.half;
    } else if (shape.type === "counter") {
        points = [{ x: shape.x1 - detail.radius, y: shape.y1 - detail.radius },
            { x: shape.x1 + detail.radius, y: shape.y1 + detail.radius },
            { x: shape.x2, y: shape.y2 }];
        padding = Math.max(1, detail.radius / 12) / 2;
    }
    const xs = points.map(p => p.x), ys = points.map(p => p.y);
    const x = Math.min.apply(null, xs) - padding, y = Math.min.apply(null, ys) - padding;
    return { x: x, y: y, width: Math.max.apply(null, xs) + padding - x,
        height: Math.max.apply(null, ys) + padding - y };
}

function controlBounds(shape, detail) {
    if (shape.type === "counter" || shape.type === "text") return bounds(shape, detail);
    const points = shape.type === "pen" ? shape.points
        : [{ x: shape.x1, y: shape.y1 }, { x: shape.x2, y: shape.y2 }];
    const xs = points.map(p => p.x), ys = points.map(p => p.y);
    const x = Math.min.apply(null, xs), y = Math.min.apply(null, ys);
    return { x: x, y: y, width: Math.max.apply(null, xs) - x, height: Math.max.apply(null, ys) - y };
}

function segmentDistance(x, y, a, b) {
    const dx = b.x - a.x, dy = b.y - a.y;
    const length = dx * dx + dy * dy;
    const t = length === 0 ? 0 : clamp(((x - a.x) * dx + (y - a.y) * dy) / length, 0, 1);
    return Math.hypot(x - a.x - t * dx, y - a.y - t * dy);
}

function inPolygon(x, y, points, tolerance) {
    let inside = false;
    for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
        const a = points[i], b = points[j];
        if (segmentDistance(x, y, a, b) <= tolerance) return true;
        if ((a.y > y) !== (b.y > y) && x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x)
            inside = !inside;
    }
    return inside;
}

function hit(shape, x, y, tolerance, detail) {
    const box = bounds(shape, detail);
    if (x < box.x - tolerance || y < box.y - tolerance
        || x > box.x + box.width + tolerance || y > box.y + box.height + tolerance) return false;
    if (shape.type === "text" || AnnotationTools.isEffect(shape.type)) return true;
    if (shape.type === "arrow")
        return inPolygon(x, y, detail.polygon, tolerance)
            || Math.hypot(x - shape.x1, y - shape.y1) <= detail.half + tolerance;
    if (shape.type === "counter")
        return Math.hypot(x - shape.x1, y - shape.y1) <= detail.radius + Math.max(1, detail.radius / 12) / 2 + tolerance
            || (detail.polygon.length > 0 && inPolygon(x, y, detail.polygon, tolerance));
    const left = Math.min(shape.x1, shape.x2), top = Math.min(shape.y1, shape.y2);
    const width = Math.abs(shape.x2 - shape.x1), height = Math.abs(shape.y2 - shape.y1);
    const stroke = shape.width / 2 + tolerance;
    if (shape.type === "fill") {
        if (!shape.rounded) return true;
        const radius = Math.min(shape.width * 2, width / 2, height / 2);
        const dx = Math.min(x - left, left + width - x);
        const dy = Math.min(y - top, top + height - y);
        // The renderer uses quadratic corners, whose curve is sqrt(x/r) + sqrt(y/r) = 1.
        return radius === 0 || dx >= radius || dy >= radius
            || Math.sqrt(clamp((dx + tolerance) / radius, 0, 1))
                + Math.sqrt(clamp((dy + tolerance) / radius, 0, 1)) >= 1;
    }
    if (shape.type === "rect") {
        if (!shape.rounded)
            return x <= left + stroke || x >= left + width - stroke
                || y <= top + stroke || y >= top + height - stroke;
        const radius = Math.min(shape.width * 2, width / 2, height / 2);
        const cx = clamp(x, left + radius, left + width - radius);
        const cy = clamp(y, top + radius, top + height - radius);
        if (cx !== x && cy !== y)
            return Math.abs(Math.hypot(x - cx, y - cy) - radius) <= stroke;
        return x <= left + stroke || x >= left + width - stroke
            || y <= top + stroke || y >= top + height - stroke;
    }
    if (shape.type === "ellipse" && width > 0 && height > 0) {
        const rx = width / 2, ry = height / 2;
        const dx = x - left - rx, dy = y - top - ry;
        const outer = dx * dx / Math.pow(rx + stroke, 2) + dy * dy / Math.pow(ry + stroke, 2);
        const inner = rx <= stroke || ry <= stroke ? Infinity
            : dx * dx / Math.pow(rx - stroke, 2) + dy * dy / Math.pow(ry - stroke, 2);
        return outer <= 1 && inner >= 1;
    }
    const points = shape.type === "pen" ? shape.points
        : [{ x: shape.x1, y: shape.y1 }, { x: shape.x2, y: shape.y2 }];
    if (points.length === 1) return Math.hypot(x - points[0].x, y - points[0].y) <= stroke;
    for (let i = 1; i < points.length; ++i)
        if (segmentDistance(x, y, points[i - 1], points[i]) <= stroke) return true;
    return false;
}

function move(shape, dx, dy, box, imageWidth, imageHeight) {
    const result = copy(shape);
    if (dx !== 0 && box.width <= imageWidth) dx = clamp(dx, -box.x, imageWidth - box.x - box.width);
    if (dy !== 0 && box.height <= imageHeight) dy = clamp(dy, -box.y, imageHeight - box.y - box.height);
    result.x1 += dx;
    result.y1 += dy;
    if (result.x2 !== undefined) result.x2 += dx;
    if (result.y2 !== undefined) result.y2 += dy;
    if (result.points)
        result.points = result.points.map(p => ({ x: p.x + dx, y: p.y + dy }));
    return result;
}

function handles(box) {
    return [{ x: box.x, y: box.y }, { x: box.x + box.width, y: box.y },
        { x: box.x + box.width, y: box.y + box.height }, { x: box.x, y: box.y + box.height }];
}

function handleAt(corners, x, y, tolerance) {
    for (let i = corners.length - 1; i >= 0; --i)
        if (Math.abs(x - corners[i].x) <= tolerance && Math.abs(y - corners[i].y) <= tolerance) return i;
    return -1;
}

function scaledBox(box, corner, factor) {
    const fixed = handles(box)[(corner + 2) % 4];
    const width = box.width * factor, height = box.height * factor;
    return { x: corner === 0 || corner === 3 ? fixed.x - width : fixed.x,
        y: corner === 0 || corner === 1 ? fixed.y - height : fixed.y, width: width, height: height };
}

function resizedBox(box, corner, x, y, imageWidth, imageHeight, uniform) {
    const corners = handles(box), fixed = corners[(corner + 2) % 4];
    const left = corner === 0 || corner === 3, top = corner === 0 || corner === 1;
    x = clamp(x, 0, imageWidth);
    y = clamp(y, 0, imageHeight);
    // Keep handles on their original side so a resize cannot flip the object.
    x = left ? Math.min(x, fixed.x - 2) : Math.max(x, fixed.x + 2);
    y = top ? Math.min(y, fixed.y - 2) : Math.max(y, fixed.y + 2);
    if (uniform) {
        let factor = Math.max(Math.abs(x - fixed.x) / box.width, Math.abs(y - fixed.y) / box.height);
        factor = Math.min(factor, (left ? fixed.x : imageWidth - fixed.x) / box.width,
            (top ? fixed.y : imageHeight - fixed.y) / box.height);
        return scaledBox(box, corner, factor);
    }
    return { x: Math.min(x, fixed.x), y: Math.min(y, fixed.y),
        width: Math.abs(x - fixed.x), height: Math.abs(y - fixed.y) };
}

function resize(shape, before, after) {
    const result = copy(shape);
    const sx = after.width / Math.max(before.width, 0.001);
    const sy = after.height / Math.max(before.height, 0.001);
    function point(x, y) {
        return { x: after.x + (x - before.x) * sx, y: after.y + (y - before.y) * sy };
    }
    let p = point(shape.x1, shape.y1);
    result.x1 = p.x;
    result.y1 = p.y;
    if (shape.x2 !== undefined) {
        p = point(shape.x2, shape.y2);
        result.x2 = p.x;
        result.y2 = p.y;
    }
    if (shape.points) result.points = shape.points.map(p => point(p.x, p.y));
    return result;
}
