function clamp(value, low, high) {
    return Math.max(low, Math.min(value, high));
}

function size(value) {
    return clamp(Math.round(value), 1, 100);
}

function counterRadius(width) {
    return 10 + size(width) * 2.5;
}

// Matches Flameshot's perceived-brightness test, so red bubbles keep white numbers.
function contrastColor(color) {
    const hex = String(color).slice(-6);
    const channel = i => parseInt(hex.slice(i, i + 2), 16);
    return 0.3 * channel(0) + 0.59 * channel(2) + 0.11 * channel(4) < 127.5 ? "#ffffff" : "#000000";
}

const effects = ["conceal", "pixelate", "blur", "solid", "invert"];

function isEffect(type) {
    return effects.indexOf(type) >= 0;
}

function usesColor(type) {
    return ["pixelate", "blur", "invert"].indexOf(type) < 0;
}

function cellSize(width) {
    return size(width) * 4;
}

function blurRadius(width) {
    return size(width) * 2;
}

// outward to whole pixels: no partly covered fringe
function effectBox(s, width, height) {
    const x = clamp(Math.floor(Math.min(s.x1, s.x2)), 0, width);
    const y = clamp(Math.floor(Math.min(s.y1, s.y2)), 0, height);
    return { x: x, y: y, width: clamp(Math.ceil(Math.max(s.x1, s.x2)), 0, width) - x,
        height: clamp(Math.ceil(Math.max(s.y1, s.y2)), 0, height) - y };
}

function create(type, x, y, color, width, rounded, number) {
    const shape = { type: type, x1: x, y1: y, x2: x, y2: y,
        // A marker needs a broad band at the same size setting as the pen.
        color: String(color), width: size(width) * (type === "marker" ? 10 : 1), rounded: isEffect(type) ? false : rounded,
        opacity: type === "marker" ? 0.35 : 1,
        points: type === "pen" ? [{ x: x, y: y }] : [] };
    if (type === "counter") {
        shape.number = number;
        shape.radius = counterRadius(width);
        shape.textColor = contrastColor(color);
    }
    return shape;
}

function update(shape, x, y, constrained, width, height) {
    let dx = x - shape.x1;
    let dy = y - shape.y1;
    if (constrained && shape.type !== "pen") {
        if (["rect", "fill", "ellipse"].indexOf(shape.type) !== -1 || isEffect(shape.type)) {
            const side = Math.max(Math.abs(dx), Math.abs(dy));
            dx = (dx < 0 ? -1 : 1) * side;
            dy = (dy < 0 ? -1 : 1) * side;
        } else {
            const angle = Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) * Math.PI / 4;
            const length = Math.hypot(dx, dy);
            dx = Math.cos(angle) * length;
            dy = Math.sin(angle) * length;
        }
        // Shorten the whole vector at an edge so the constraint survives clipping.
        const fitX = Math.abs(dx) < 0.000001 ? 1 : (dx > 0 ? width - shape.x1 : shape.x1) / Math.abs(dx);
        const fitY = Math.abs(dy) < 0.000001 ? 1 : (dy > 0 ? height - shape.y1 : shape.y1) / Math.abs(dy);
        const fit = Math.min(1, fitX, fitY);
        dx *= fit;
        dy *= fit;
    }
    shape.x2 = clamp(shape.x1 + dx, 0, width);
    shape.y2 = clamp(shape.y1 + dy, 0, height);
    if (shape.type === "pen") {
        const last = shape.points[shape.points.length - 1];
        if (last.x !== shape.x2 || last.y !== shape.y2)
            shape.points.push({ x: shape.x2, y: shape.y2 });
    }
}

function rectanglePath(ctx, x, y, width, height, radius) {
    const r = Math.min(radius, width / 2, height / 2);
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + width - r, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + r);
    ctx.lineTo(x + width, y + height - r);
    ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
    ctx.lineTo(x + r, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
}

function arrowGeometry(s) {
    const length = Math.hypot(s.x2 - s.x1, s.y2 - s.y1);
    const angle = Math.atan2(s.y2 - s.y1, s.x2 - s.x1);
    const ux = Math.cos(angle), uy = Math.sin(angle);
    const head = Math.min(length, Math.max(12, s.width * 4) * Math.cos(Math.PI / 6));
    const wing = head * Math.tan(Math.PI / 6);
    const half = Math.min(s.width / 2, wing);
    const bx = s.x2 - head * ux, by = s.y2 - head * uy;
    return { length: length, angle: angle, half: half, polygon: [
        { x: s.x1 - uy * half, y: s.y1 + ux * half },
        { x: bx - uy * half, y: by + ux * half },
        { x: bx - uy * wing, y: by + ux * wing },
        { x: s.x2, y: s.y2 },
        { x: bx + uy * wing, y: by - ux * wing },
        { x: bx + uy * half, y: by - ux * half },
        { x: s.x1 + uy * half, y: s.y1 - ux * half }
    ] };
}

function arrowPath(ctx, s) {
    const geometry = arrowGeometry(s);
    if (geometry.length === 0) return;
    // One silhouette keeps the shaft's round cap from protruding beyond the tip.
    const points = geometry.polygon;
    ctx.moveTo(points[0].x, points[0].y);
    for (let i = 1; i < points.length; ++i) ctx.lineTo(points[i].x, points[i].y);
    ctx.arc(s.x1, s.y1, geometry.half, geometry.angle - Math.PI / 2,
        geometry.angle - 3 * Math.PI / 2, true);
    ctx.closePath();
}

function textFont(font) {
    return (font.italic ? "italic " : "") + (font.bold ? "bold " : "")
        + font.size + "px \"" + font.family.replace(/"/g, "") + "\"";
}

// Uses the line metrics stored at layout time so export never re-measures text.
function textPath(ctx, s) {
    const layout = s.layout;
    const box = s.x2 - s.x1;
    ctx.font = textFont(s.font);
    ctx.textBaseline = "alphabetic";
    s.text.split("\n").forEach((line, i) => {
        const width = layout.widths[i];
        const x = s.x1 + (s.font.align === "center" ? (box - width) / 2
            : s.font.align === "right" ? box - width : 0);
        const baseline = s.y1 + i * layout.lineHeight + layout.ascent;
        if (line.length > 0) ctx.fillText(line, x, baseline);
        if (s.font.underline)
            ctx.fillRect(x, baseline + layout.underline, width, layout.thickness);
        if (s.font.strikeout)
            ctx.fillRect(x, baseline - layout.strike - layout.thickness / 2, width, layout.thickness);
    });
}

function counterGeometry(s) {
    const distance = Math.hypot(s.x2 - s.x1, s.y2 - s.y1);
    const angle = Math.atan2(s.y2 - s.y1, s.x2 - s.x1);
    const spread = distance > s.radius ? Math.min(Math.acos(s.radius / distance), Math.PI / 5) : 0;
    return { radius: s.radius, angle: angle, spread: spread, polygon: spread > 0 ? [
        { x: s.x2, y: s.y2 },
        { x: s.x1 + s.radius * Math.cos(angle + spread), y: s.y1 + s.radius * Math.sin(angle + spread) },
        { x: s.x1 + s.radius * Math.cos(angle - spread), y: s.y1 + s.radius * Math.sin(angle - spread) }
    ] : [] };
}

function counterPath(ctx, s) {
    const r = s.radius;
    const geometry = counterGeometry(s);
    if (geometry.polygon.length > 0) {
        // The pointer base meets the bubble so bubble and pointer share one outline.
        ctx.moveTo(s.x2, s.y2);
        ctx.arc(s.x1, s.y1, r, geometry.angle + geometry.spread,
            geometry.angle - geometry.spread + Math.PI * 2, false);
        ctx.closePath();
    } else {
        ctx.arc(s.x1, s.y1, r, 0, Math.PI * 2, false);
    }
    ctx.fill();
    ctx.strokeStyle = s.textColor;
    ctx.lineWidth = Math.max(1, r / 12);
    ctx.stroke();
    const digits = String(s.number).length;
    ctx.fillStyle = s.textColor;
    ctx.font = "bold " + Math.round(r * (digits <= 1 ? 1.15 : digits === 2 ? 0.95 : 0.72)) + "px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(String(s.number), s.x1, s.y1);
    ctx.textAlign = "start";
}

// running average of shifted copies, all native draws
function boxFilter(ctx, r, n, horizontal) {
    if (n <= 1) return;
    const image = ctx.getImageData(r.x, r.y, r.width, r.height);
    const first = -Math.floor((n - 1) / 2);
    let count = 1;
    for (let offset = first; offset < first + n; ++offset) {
        if (offset === 0) continue;
        ctx.globalAlpha = 1 / ++count;
        ctx.drawImage(image, r.x + (horizontal ? offset : 0), r.y + (horizontal ? 0 : offset));
    }
    ctx.globalAlpha = 1;
}

function blurBox(ctx, b, radius) {
    const f = Math.max(1, Math.round(Math.sqrt(radius)));
    const small = { x: b.x, y: b.y, width: Math.ceil(b.width / f), height: Math.ceil(b.height / f) };
    if (f > 1) {
        boxFilter(ctx, b, f, true);
        boxFilter(ctx, b, f, false);
        ctx.drawImage(ctx.getImageData(b.x, b.y, b.width, b.height), 0, 0, b.width, b.height,
            b.x, b.y, b.width / f, b.height / f);
    }
    const n = Math.max(2, Math.round(1.2 * radius / f));
    for (let pass = 0; pass < 2; ++pass) {
        boxFilter(ctx, small, n, true);
        boxFilter(ctx, small, n, false);
    }
    if (f > 1) {
        ctx.drawImage(ctx.getImageData(small.x, small.y, small.width, small.height), 0, 0,
            small.width, small.height, b.x, b.y, small.width * f, small.height * f);
        boxFilter(ctx, b, f, true);
        boxFilter(ctx, b, f, false);
    }
}

function pixelateBox(ctx, b, cell) {
    const n = Math.min(cell, 32); // centre window bounds cost
    boxFilter(ctx, b, n, true);
    boxFilter(ctx, b, n, false);
    const data = ctx.getImageData(b.x, b.y, b.width, b.height).data;
    for (let y = 0; y < b.height; y += cell)
        for (let x = 0; x < b.width; x += cell) {
            const i = (Math.min(y + (cell >> 1), b.height - 1) * b.width
                + Math.min(x + (cell >> 1), b.width - 1)) * 4;
            ctx.fillStyle = Qt.rgba(data[i] / 255, data[i + 1] / 255, data[i + 2] / 255, 1);
            ctx.fillRect(b.x + x, b.y + y, cell, cell);
        }
}

function cellShade(i, j) {
    let h = (Math.imul(i, 374761393) + Math.imul(j, 668265263)) | 0;
    h = Math.imul(h ^ (h >>> 13), 1274126177);
    return ((h ^ (h >>> 16)) >>> 0) % 5;
}

// from colour and grid position only; never reads pixels
function concealBox(ctx, b, color, cell) {
    const hex = String(color).slice(-6);
    const channels = [0, 2, 4].map(i => parseInt(hex.slice(i, i + 2), 16));
    const shades = [0, 1, 2, 3, 4].map(level => {
        const t = (level - 2) * 0.12;
        const c = channels.map(v => Math.round(t > 0 ? v + (255 - v) * t : v * (1 + t)) / 255);
        return Qt.rgba(c[0], c[1], c[2], 1);
    });
    ctx.fillStyle = shades[2];
    ctx.fillRect(b.x, b.y, b.width, b.height);
    for (let j = 0; j * cell < b.height; ++j)
        for (let i = 0; i * cell < b.width; ++i) {
            const level = cellShade(i, j);
            if (level === 2) continue;
            ctx.fillStyle = shades[level];
            ctx.fillRect(b.x + i * cell, b.y + j * cell, cell, cell);
        }
}

function renderEffect(ctx, s, width, height) {
    const b = effectBox(s, width, height);
    if (b.width === 0 || b.height === 0) return;
    ctx.save();
    ctx.globalAlpha = 1; // A preceding highlighter must not weaken concealment.
    ctx.globalCompositeOperation = "source-over";
    ctx.beginPath();
    ctx.rect(b.x, b.y, b.width, b.height);
    ctx.clip();
    if (s.type === "blur") {
        blurBox(ctx, b, blurRadius(s.width));
    } else if (s.type === "pixelate") {
        pixelateBox(ctx, b, cellSize(s.width));
    } else if (s.type === "solid") {
        ctx.fillStyle = "#" + String(s.color).slice(-6);
        ctx.fillRect(b.x, b.y, b.width, b.height);
    } else if (s.type === "invert") {
        ctx.globalCompositeOperation = "qt-difference";
        ctx.fillStyle = "#ffffff";
        ctx.fillRect(b.x, b.y, b.width, b.height);
    } else {
        concealBox(ctx, b, s.color, cellSize(s.width));
    }
    ctx.restore();
}

// source first, then objects in order; one buffer pixel per source pixel
function render(ctx, shapes, image, width, height, scale) {
    ctx.reset();
    ctx.scale(scale, scale);
    ctx.drawImage(image, 0, 0, width, height);
    for (const s of shapes) {
        if (isEffect(s.type)) {
            renderEffect(ctx, s, width, height);
            continue;
        }
        ctx.strokeStyle = s.color;
        ctx.fillStyle = s.color;
        ctx.lineWidth = s.width;
        ctx.globalAlpha = s.opacity;
        ctx.lineCap = s.type === "marker" ? "butt" : "round";
        ctx.lineJoin = "round";
        ctx.beginPath();
        const x = Math.min(s.x1, s.x2);
        const y = Math.min(s.y1, s.y2);
        const w = Math.abs(s.x2 - s.x1);
        const h = Math.abs(s.y2 - s.y1);
        if (s.type === "rect" || s.type === "fill") {
            rectanglePath(ctx, x, y, w, h, s.rounded ? s.width * 2 : 0);
            if (s.type === "fill") ctx.fill();
            else ctx.stroke();
        } else if (s.type === "ellipse") {
            ctx.ellipse(x, y, w, h);
            ctx.stroke();
        } else if (s.type === "pen") {
            const points = s.points;
            ctx.moveTo(points[0].x, points[0].y);
            for (let i = 1; i < points.length; ++i)
                ctx.lineTo(points[i].x, points[i].y);
            if (points.length === 1) {
                ctx.arc(points[0].x, points[0].y, s.width / 2, 0, Math.PI * 2);
                ctx.fill();
            } else ctx.stroke();
        } else if (s.type === "text") {
            textPath(ctx, s);
        } else if (s.type === "counter") {
            counterPath(ctx, s);
        } else if (s.type === "arrow") {
            arrowPath(ctx, s);
            ctx.fill();
        } else {
            ctx.moveTo(s.x1, s.y1);
            ctx.lineTo(s.x2, s.y2);
            ctx.stroke();
        }
    }
}
