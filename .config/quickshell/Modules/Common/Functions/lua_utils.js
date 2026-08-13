function stringLiteral(value) {
    const text = String(value);
    let equals = "";

    while (text.includes(`]${equals}]`))
        equals += "=";

    return `[${equals}[${text}]${equals}]`;
}
