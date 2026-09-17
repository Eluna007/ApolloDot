import QtQuick
import qs.Services
import "../../Common/functions/SpotlightTemplates.js" as Templates

QtObject {
    id: root
    property string mode: ""
    property string templateKind: ""
    property string sourceZone: "UTC"
    property string targetZone: "Asia/Tokyo"
    property string driverAmount: "09:00"
    property int driverSide: 0
    property int activeSlot: 0
    property string draft: ""
    property bool choosing: false
    property bool editingUnit: false
    property int selected: 0
    readonly property bool timeMode: mode === "time"
    readonly property bool active: timeMode
    readonly property bool choosingTemplate: active && !templateKind
    readonly property bool editing: active && !!templateKind
    readonly property bool nowTemplate: templateKind === "now"
    readonly property string expression: !editing ? "" : nowTemplate ? "now to " + targetZone :
                                                                       Templates.timeExpression(driverAmount,
                                                                                                driverSide
                                                                                                === 0 ? sourceZone :
                                                                                                        targetZone,
                                                                                                driverSide
                                                                                                === 0 ? targetZone :
                                                                                                        sourceZone)
    readonly property bool currentResult: editing && SpotlightToolService.tool === "time"
                                          && SpotlightToolService.query === expression
                                          && SpotlightToolService.canCopy
    readonly property string answer: currentResult && SpotlightToolService.result.target
                                     ? Templates.editableTime(SpotlightToolService.result.target.datetime) :
                                       ""
    readonly property var choices: {
        if (choosingTemplate)
            return [
                        {
                            text: qsTr("Now to a time zone"),
                            name: "",
                            kind: "now"
                        },
                        {
                            text: qsTr("Convert between two time zones"),
                            name: "",
                            kind: "pair"
                        }
                    ];
        if (!editing || !choosing)
            return [];
        const filter = draft.trim().toLowerCase();
        return (SpotlightToolService.catalogs.time || []).filter(item => !filter || (item.text + " "
                                                                                     + item.name).toLowerCase(
                                                                             ).includes(filter));
    }
    signal focusRequested(bool selectAll)
    signal templateSelectionRequested

    function reset() {
        templateKind = "";
        sourceZone = "UTC";
        targetZone = "Asia/Tokyo";
        driverAmount = "09:00";
        driverSide = 0;
        activeSlot = 0;
        choosing = false;
        editingUnit = false;
        draft = "";
        selected = 0;
    }
    function clearTemplate() {
        reset();
        templateSelectionRequested();
    }
    function value(slot) {
        if (slot === 1)
            return nowTemplate ? qsTr("Local time") : sourceZone;
        if (slot === 3)
            return targetZone;
        if (nowTemplate && slot === 0)
            return "now";
        return !nowTemplate && slot === driverSide ? driverAmount : answer;
    }
    function editable(slot) {
        return !nowTemplate || slot === 3;
    }
    function activate(slot) {
        activeSlot = nowTemplate ? 3 : Math.max(0, Math.min(3, slot));
        choosing = activeSlot === 1 || activeSlot === 3;
        editingUnit = false;
        draft = "";
        selected = 0;
        focusRequested(true);
    }
    function edit(slot, value) {
        if (slot === 1 || slot === 3) {
            draft = value;
            editingUnit = true;
            choosing = true;
            selected = 0;
        } else if (!nowTemplate) {
            driverSide = slot;
            driverAmount = value;
        }
    }
    function move(delta) {
        if (!choices.length)
            return false;
        selected = (selected + delta + choices.length) % choices.length;
        return true;
    }
    function choose(index) {
        const choice = choices[index];
        if (!choice)
            return false;
        if (choosingTemplate) {
            templateKind = choice.kind;
            activate(nowTemplate ? 3 : 0);
        } else {
            if (activeSlot === 1)
                sourceZone = choice.text;
            else
                targetZone = choice.text;
            choosing = false;
            editingUnit = false;
            draft = "";
            focusRequested(true);
        }
        return true;
    }
    function dismiss() {
        if (!choosing)
            return false;
        choosing = false;
        editingUnit = false;
        draft = "";
        focusRequested(true);
        return true;
    }
    function copyText(value) {
        return SpotlightToolService.copyText(value);
    }
    function copyAnswer() {
        return currentResult && SpotlightToolService.copy();
    }
    onChoicesChanged: selected = 0
}
