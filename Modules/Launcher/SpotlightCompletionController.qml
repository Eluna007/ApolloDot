import QtQuick
import qs.Services
import "../../Common/functions/SpotlightCompletion.js" as Completion
import "../../Common/functions/SpotlightCommands.js" as Commands

QtObject {
    id: root
    property string text: ""
    property int cursor: 0
    property string mode: "search"
    property bool slash: false
    property var results: []
    property string selectedId: ""
    property var choices: []
    property int selected: 0
    readonly property bool opened: choices.length > 0
    signal accepted(var value)

    function dismiss() {
        choices = [];
        selected = 0;
    }
    function move(delta) {
        if (opened)
            selected = (selected + delta + choices.length) % choices.length;
    }
    function accept() {
        if (!opened)
            return false;
        const value = Completion.accept(text, choices[selected]);
        dismiss();
        if (value)
            accepted(value);
        return !!value;
    }
    function build() {
        let range = Completion.tokenAt(text, cursor);
        let values = [];
        if (slash && range.start === 0) {
            values = Commands.entries.reduce((all, entry) => all.concat([entry.slashName].concat(
                                                                            entry.aliases || []).map(name => (
                                                                            {
                                                                                text: "/" + name,
                                                                                name: SpotlightCatalog.commandTitle(
                                                                                          entry),
                                                                                id: entry.id
                                                                            }))), []);
        } else if (mode === "commands") {
            values = SpotlightCatalog.commandMatches(text.slice(0, cursor), true).map(entry => ({
                text: entry.slashName,
                name: SpotlightCatalog.commandTitle(entry),
                id: entry.id
            }));
            range = {
                start: 0,
                end: cursor,
                prefix: ""
            };
        } else if (["calculator", "currency", "time"].includes(mode)) {
            if (mode === "calculator") {
                let start = cursor, end = cursor;
                while (start > 0 && /[A-Za-z]/.test(text.charAt(start - 1)))
                    start--;
                while (end < text.length && /[A-Za-z]/.test(text.charAt(end)))
                    end++;
                range = {
                    start: start,
                    end: end,
                    prefix: text.slice(start, cursor)
                };
                values = SpotlightToolService.candidates;
            } else {
                const before = text.slice(0, range.start).trim();
                if (mode === "currency") {
                    if (/^[+-]?[\d.]+\s+[A-Za-z]{3}$/i.test(before))
                        values = [
                                    {
                                        text: "to",
                                        name: "to"
                                    }
                                ];
                    else if (/^[+-]?[\d.]+(?:\s+[A-Za-z]{3}\s+to)?$/i.test(before))
                        values = SpotlightToolService.candidates;
                } else {
                    values = SpotlightToolService.candidates;
                    if (!before)
                        values = [
                                    {
                                        text: "now",
                                        name: "now"
                                    }
                                ];
                    else if (/^now$/i.test(before) || /\s(?:[A-Za-z_]+\/[^\s]+|UTC)$/i.test(before))
                        values = [
                                    {
                                        text: "to",
                                        name: "to"
                                    }
                                ].concat(values);
                }
            }
            // Human names and explicit aliases complete to canonical codes/names.
            const prefix = range.prefix.toLocaleLowerCase();
            values = values.filter(value => value.text.toLocaleLowerCase().startsWith(prefix) || value.name.toLocaleLowerCase(
                                                ).startsWith(prefix));
            range = Object.assign({}, range, {
                                      prefix: ""
                                  });
        } else if (["apps", "wallpapers", "settings", "actions", "search"].includes(mode) && !slash) {
            const rows = results.filter(entry => entry.provider !== "extension");
            const current = rows.find(entry => entry.id === selectedId);
            values = (current ? [current].concat(rows.filter(entry => entry !== current)) : rows).map(entry
                                                                                                      => ({
                                                                                                          text: entry.title,
                                                                                                          name: entry.title,
                                                                                                          id: entry.id,
                                                                                                          literal: true
                                                                                                      }));
            range = {
                start: 0,
                end: cursor,
                prefix: ""
            };
        }
        return Completion.candidates(text, cursor, values, range);
    }
    function tab(reverse) {
        if (opened) {
            if (reverse)
                move(-1);
            else
                accept();
            return;
        }
        choices = build();
        selected = reverse ? Math.max(0, choices.length - 1) : 0;
        if (choices.length === 1)
            accept();
    }
    onTextChanged: dismiss()
    onCursorChanged: dismiss()
    onModeChanged: dismiss()
}
