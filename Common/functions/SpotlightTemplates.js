// Templates translate editable presentation into the existing tool protocol.
function currency(text) {
    const match = /^\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+)?|…)\s+([A-Z]{3})\s*=\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+)?|…)\s+([A-Z]{3})\s*$/i.exec(text);
    return match ? {left: match[1], from: match[2].toUpperCase(), right: match[3], to: match[4].toUpperCase()} : null;
}
function currencyText(value) {
    return value.left + ' ' + value.from + ' = ' + value.right + ' ' + value.to;
}
function currencyExpression(value, side) {
    if (!value) return '';
    const amount = side === 'right' ? value.right : value.left;
    if (!/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$/.test(amount)) return '';
    return side === 'right' ? amount + ' ' + value.to + ' to ' + value.from : amount + ' ' + value.from + ' to ' + value.to;
}
function editedSide(before, after, previous) {
    if (!before || !after) return previous;
    if (before.left !== after.left) return 'left';
    if (before.right !== after.right) return 'right';
    return previous;
}
function timeExpression(text, source, target) {
    if (!target || !text.trim()) return '';
    let value = text.trim();
    if (/^\d{1,2}$/.test(value)) value = value.padStart(2, '0') + ':00';
    else if (/^\d{3,4}$/.test(value)) value = value.padStart(4, '0').replace(/(\d{2})(\d{2})/, '$1:$2');
    return value + (source ? ' ' + source : '') + ' to ' + target;
}
