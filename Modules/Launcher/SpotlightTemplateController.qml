import QtQuick
import qs.Services
import "../../Common/functions/SpotlightTemplates.js" as Templates

QtObject {
    id: root
    property string mode: ""
    property string text: ""
    property int cursor: 0
    property bool applying: false
    property var pair: ({
                            left: "1",
                            from: "USD",
                            right: "…",
                            to: "EUR"
                        })
    property string amountSide: "left"
    property string unitSide: "left"
    property string expression: ""
    property string sourceZone: ""
    property string targetZone: ""
    property bool choosingSource: false
    property int selected: -1
    readonly property bool currencyMode: mode === "currency"
    readonly property bool timeMode: mode === "time"
    readonly property bool choosingTime: timeMode && (!targetZone || choosingSource)
    readonly property bool active: currencyMode || timeMode
    readonly property string heading: currencyMode ? (unitSide === "left" ? qsTr("Source currency") : qsTr(
                                                                                "Target currency")) :
                                                     choosingSource ? qsTr("Source time zone") : qsTr(
                                                                          "Target time zone")
    readonly property string direction: (sourceZone || qsTr("Local time")) + " → " + targetZone
    readonly property var choices: {
        if (!active || (timeMode && !choosingTime))
            return [];
        const filter = timeMode ? text.trim().toLowerCase() : "";
        const seen = {};
        return SpotlightToolService.candidates.filter(item => {
            if (filter && !(item.text + " " + item.name).toLowerCase().includes(filter))
                return false;
            if (seen[item.text])
                return false;
            seen[item.text] = true;
            return true;
        });
    }
    signal replaceText(string value, int start, int end)

    function write(value, start, end) {
        applying = true;
        replaceText(value, start, end);
        applying = false;
    }
    function reset() {
        selected = -1;
        expression = "";
        choosingSource = false;
        sourceZone = "";
        targetZone = "";
        amountSide = "left";
        unitSide = "left";
        if (currencyMode) {
            const initial = /^([+-]?[\d.]+)\s+([A-Z]{3})\s+to\s+([A-Z]{3})$/i.exec(text.trim());
            pair = {
                left: initial ? initial[1] : "1",
                from: initial ? initial[2].toUpperCase() : "USD",
                right: "…",
                to: initial ? initial[3].toUpperCase() : "EUR"
            };
            expression = Templates.currencyExpression(pair, amountSide);
            write(Templates.currencyText(pair), 0, pair.left.length);
        } else if (timeMode) {
            write("", 0, 0);
        }
    }
    function edit() {
        if (applying || !active)
            return;
        selected = -1;
        if (currencyMode) {
            const next = Templates.currency(text);
            amountSide = Templates.editedSide(pair, next, amountSide);
            const request = Templates.currencyExpression(next, amountSide);
            const unchanged = request === expression;
            expression = request;
            if (next) {
                pair = next;
                const editedText = text;
                Qt.callLater(() => {
                    if (!root.currencyMode || root.text !== editedText)
                        return;
                    if (unchanged && SpotlightToolService.canCopy)
                        root.updateAnswer();
                    else
                        root.clearAnswer();
                });
            }
        } else {
            expression = choosingTime ? "" : Templates.timeExpression(text, sourceZone, targetZone);
        }
    }
    function clearAnswer() {
        const position = cursor;
        const oldEquals = text.indexOf("=");
        pair = Object.assign({}, pair, amountSide === "left" ? {
                                                                   right: "…"
                                                               } : {
                                 left: "…"
                             });
        const value = Templates.currencyText(pair);
        const nextCursor = amountSide === "right" ? position + value.indexOf("=") - oldEquals : position;
        write(value, Math.max(0, Math.min(nextCursor, value.length)), Math.max(0, Math.min(nextCursor,
                                                                                           value.length)));
    }
    function move(delta) {
        if (!choices.length)
            return false;
        selected = selected < 0 ? (delta > 0 ? 0 : choices.length - 1) : (selected + delta + choices.length)
                                  % choices.length;
        return true;
    }
    function choose(index) {
        const choice = choices[index];
        if (!choice)
            return false;
        if (currencyMode) {
            pair = Object.assign({}, pair, unitSide === "left" ? {
                                                                     from: choice.text
                                                                 } : {
                                     to: choice.text
                                 });
            const request = Templates.currencyExpression(pair, amountSide);
            const unchanged = request === expression;
            expression = request;
            pair = Object.assign({}, pair, amountSide === "left" ? {
                                                                       right: "…"
                                                                   } : {
                                     left: "…"
                                 });
            const value = Templates.currencyText(pair);
            const start = amountSide === "left" ? 0 : value.indexOf("=") + 2;
            write(value, start, start + (amountSide === "left" ? pair.left.length : pair.right.length));
            if (unchanged && SpotlightToolService.canCopy)
                updateAnswer();
        } else {
            if (choosingSource) {
                sourceZone = choice.text;
                choosingSource = false;
            } else
                targetZone = choice.text;
            write("", 0, 0);
            expression = "";
        }
        selected = -1;
        return true;
    }
    function changeSource() {
        choosingSource = true;
        expression = "";
        write("", 0, 0);
    }
    function backspace() {
        if (!timeMode || text.length || !targetZone || choosingSource)
            return false;
        targetZone = "";
        selected = -1;
        expression = "";
        return true;
    }
    function updateAnswer() {
        if (!currencyMode || !SpotlightToolService.canCopy || !Templates.currency(text))
            return;
        const result = SpotlightToolService.result;
        if (typeof result.converted !== "string")
            return;
        const start = cursor;
        const oldEquals = text.indexOf("=");
        pair = Object.assign({}, pair, amountSide === "left" ? {
                                                                   right: result.converted
                                                               } : {
                                 left: result.converted
                             });
        // An answer update is presentation only: never submit it as a new edit.
        const value = Templates.currencyText(pair);
        const position = amountSide === "right" ? start + value.indexOf("=") - oldEquals : start;
        write(value, Math.min(position, value.length), Math.min(position, value.length));
    }
    onTextChanged: edit()
    onCursorChanged: {
        if (currencyMode && !applying)
            unitSide = cursor > text.indexOf("=") ? "right" : "left";
    }
    onChoicesChanged: selected = -1
}
