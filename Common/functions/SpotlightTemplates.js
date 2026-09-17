function timeExpression(text, source, target) {
    if (!target || !text.trim()) return '';
    let value = text.trim();
    if (/^\d{1,2}$/.test(value)) value = value.padStart(2, '0') + ':00';
    else if (/^\d{3,4}$/.test(value)) value = value.padStart(4, '0').replace(/(\d{2})(\d{2})/, '$1:$2');
    return value + (source ? ' ' + source : '') + ' to ' + target;
}
