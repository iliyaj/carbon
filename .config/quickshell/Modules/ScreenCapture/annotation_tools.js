function clamp(value, low, high) {
    return Math.max(low, Math.min(value, high));
}

function size(value) {
    return clamp(Math.round(value), 1, 100);
}

function create(type, x, y, color, width, rounded) {
    return { type: type, x1: x, y1: y, x2: x, y2: y,
        // A marker needs a broad band at the same size setting as the pen.
        color: String(color), width: size(width) * (type === "marker" ? 10 : 1), rounded: rounded,
        opacity: type === "marker" ? 0.35 : 1,
        points: type === "pen" ? [{ x: x, y: y }] : [] };
}

function update(shape, x, y, constrained, width, height) {
    let dx = x - shape.x1;
    let dy = y - shape.y1;
    if (constrained && shape.type !== "pen") {
        if (["rect", "fill", "ellipse"].indexOf(shape.type) !== -1) {
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

function arrowPath(ctx, s) {
    const length = Math.hypot(s.x2 - s.x1, s.y2 - s.y1);
    if (length === 0) return;
    const angle = Math.atan2(s.y2 - s.y1, s.x2 - s.x1);
    const ux = Math.cos(angle), uy = Math.sin(angle);
    const head = Math.min(length, Math.max(12, s.width * 4) * Math.cos(Math.PI / 6));
    const wing = head * Math.tan(Math.PI / 6);
    const half = Math.min(s.width / 2, wing);
    const bx = s.x2 - head * ux, by = s.y2 - head * uy;
    // One silhouette keeps the shaft's round cap from protruding beyond the tip.
    ctx.moveTo(s.x1 - uy * half, s.y1 + ux * half);
    ctx.lineTo(bx - uy * half, by + ux * half);
    ctx.lineTo(bx - uy * wing, by + ux * wing);
    ctx.lineTo(s.x2, s.y2);
    ctx.lineTo(bx + uy * wing, by - ux * wing);
    ctx.lineTo(bx + uy * half, by - ux * half);
    ctx.lineTo(s.x1 + uy * half, s.y1 - ux * half);
    ctx.arc(s.x1, s.y1, half, angle - Math.PI / 2, angle - 3 * Math.PI / 2, true);
    ctx.closePath();
}

function render(ctx, shapes) {
    ctx.reset();
    for (const s of shapes) {
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
            ctx.font = "bold 22px sans-serif";
            ctx.textBaseline = "top";
            ctx.fillText(s.text, s.x1, s.y1);
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
