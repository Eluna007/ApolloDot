// QML and JavaScript both use UTF-16 offsets. Never apply Python character
// offsets to TextInput: backend catalogs contain names, not replacement ranges.
function tokenAt(text, cursor) {
    cursor = Math.max(0, Math.min(text.length, cursor));
    let start = cursor;
    let end = cursor;
    while (start > 0 && !/\s/.test(text.charAt(start - 1))) start--;
    while (end < text.length && !/\s/.test(text.charAt(end))) end++;
    return { start: start, end: end, prefix: text.slice(start, cursor) };
}

function candidates(text, cursor, values, range) {
    const token = range || tokenAt(text, cursor);
    const prefix = token.prefix.toLocaleLowerCase();
    return values.filter(value => String(value.text).toLocaleLowerCase().indexOf(prefix) === 0)
        .slice(0, 8).map(value => Object.assign({}, value, { start: token.start, end: token.end }));
}

function accept(text, candidate) {
    if (!candidate || candidate.start < 0 || candidate.end < candidate.start
            || candidate.end > text.length) return null;
    const replacement = String(candidate.text);
    return { text: text.slice(0, candidate.start) + replacement + text.slice(candidate.end),
        cursor: candidate.start + replacement.length, selectionId: candidate.id || "",
        literal: !!candidate.literal };
}
