.pragma library

// Work only in the unscaled coordinate system. Animated icon positions must
// never feed back into magnification, otherwise the dock chases the pointer.
function layout(kinds, preferredSize, available, magnification, separatorSize, pointer) {
    const gap = 8;
    const padding = 12;
    const count = kinds.length;
    const apps = kinds.filter(kind => kind !== "separator").length;
    const separators = count - apps;
    const maximum = Math.max(1, Math.min(2, magnification));
    const fixed = separators * separatorSize + count * gap + padding * 2;
    const reserve = Math.min(apps, 5) * (maximum - 1);
    const size = Math.max(32, Math.min(preferredSize, (available - fixed) / Math.max(1, apps + reserve)));
    const baseLength = fixed + apps * size;
    let baseCursor = padding;
    let cursor = padding;
    const slots = [];
    for (let index = 0; index < count; ++index) {
        const separator = kinds[index] === "separator";
        const baseSpan = (separator ? separatorSize : size) + gap;
        const center = baseCursor + baseSpan / 2;
        const distance = (pointer - center) / (size + gap);
        const scale = separator || !isFinite(pointer) ? 1 : 1 + (maximum - 1) * Math.exp(-distance * distance / 2);
        const span = (separator ? separatorSize : size * scale) + gap;
        slots.push({ center: center, start: cursor, span: span, size: size * scale });
        baseCursor += baseSpan;
        cursor += span;
    }
    return { size: size, baseLength: baseLength, length: cursor + padding, slots: slots,
             overflow: baseLength + reserve * size > available };
}

function insertionIndex(slots, position) {
    for (let index = 0; index < slots.length; ++index) {
        if (position < slots[index].start + slots[index].span / 2)
            return index;
    }
    return slots.length;
}

function removalDistance(edge, x, y, width, height, edgeOffset) {
    if (edge === "left") return x - edgeOffset;
    if (edge === "right") return width - x - edgeOffset;
    return height - y - edgeOffset;
}
